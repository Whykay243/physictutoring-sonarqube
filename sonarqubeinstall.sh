#!/bin/bash
exec > /var/log/sonarqube-setup.log 2>&1
set -x
set -euo pipefail

# 1. Variables & Random DB Password
SQ_VERSION="9.9.6.72016"
DB_NAME="sonarqube"
DB_USER="sonarqube"
DB_PASS=$(openssl rand -base64 32)   # secure random password
SQ_USER="sonarqube"

# 2. System Update & Prereqs
apt-get update -y
DEBIAN_FRONTEND=noninteractive \
  apt-get install -y --no-install-recommends \
    unzip wget gnupg2 software-properties-common default-jdk \
    postgresql postgresql-contrib ufw

# 3. PostgreSQL Setup
sudo -u postgres psql <<-EOSQL
CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';
CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};
GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};
EOSQL

# 4. Download & Install SonarQube
mkdir -p /opt/sonarqube
cd /opt/sonarqube
wget -q https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SQ_VERSION}.zip
unzip -q sonarqube-${SQ_VERSION}.zip
mv sonarqube-${SQ_VERSION}/* ./
rm -rf sonarqube-${SQ_VERSION}.zip

# 5. Service User & Permissions
useradd --system --no-create-home --shell /usr/sbin/nologin ${SQ_USER}
chown -R ${SQ_USER}:${SQ_USER} /opt/sonarqube

# 6. Store DB Credentials Securely
install -o ${SQ_USER} -g ${SQ_USER} -m 600 /dev/null /etc/sonarqube-db.conf
cat <<EOF > /etc/sonarqube-db.conf
sonar.jdbc.username=${DB_USER}
sonar.jdbc.password=${DB_PASS}
sonar.jdbc.url=jdbc:postgresql://localhost/${DB_NAME}
EOF

# 7. System Tuning
cat <<EOF >> /etc/sysctl.conf
vm.max_map_count=524288
fs.file-max=131072
EOF
sysctl -p

cat <<EOF > /etc/security/limits.d/99-sonarqube.conf
${SQ_USER}   -   nofile    131072
${SQ_USER}   -   nproc     8192
EOF

# 8. Configure sonar.properties
conf="/opt/sonarqube/conf/sonar.properties"
sed -i "s|#sonar.jdbc.username=.*|sonar.jdbc.username=${DB_USER}|" $conf
sed -i "s|#sonar.jdbc.password=.*|sonar.jdbc.password=${DB_PASS}|" $conf
sed -i "s|#sonar.jdbc.url=.*|sonar.jdbc.url=jdbc:postgresql://localhost/${DB_NAME}|" $conf
cat <<EOF >> $conf

# Bind to all interfaces
sonar.web.host=0.0.0.0
sonar.web.port=9000
sonar.web.javaAdditionalOpts=-server
EOF

# 9. Create systemd Unit
cat <<'EOF' > /etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube service
After=network.target postgresql.service

[Service]
Type=simple
User=sonarqube
Group=sonarqube
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
Restart=on-failure
LimitNOFILE=131072
LimitNPROC=8192

[Install]
WantedBy=multi-user.target
EOF

# 10. Enable & Start Services
systemctl daemon-reload
systemctl enable sonarqube
systemctl start sonarqube

# 11. Firewall Hardening
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH comment 'allow SSH'
ufw allow 9000 comment 'allow SonarQube'
ufw logging on
ufw --force enable

# 12. Cleanup
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "SonarQube ${SQ_VERSION} setup completed at $(date)"
