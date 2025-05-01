#!/bin/bash
set -euo pipefail

LOGFILE=/var/log/sonarqube_install.log
exec > >(tee -a "$LOGFILE") 2>&1

echo "=== SonarQube Installation Script Started ==="

# 1. Must run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root." >&2
    exit 1
fi

# Variables (customize as needed)
SONAR_VERSION="25.2.0.102705"      # e.g., 2025 LTA
DB_USER="sonar"
DB_PASS="${DB_PASS:-ChangeMe123}"  # Set DB_PASS env or change here
DB_NAME="sonarqube"

echo "[Info] Updating package lists..."
apt-get update -y

# 2. Sysctl tuning for Elasticsearch (SonarQube requirement: vm.max_map_count>=524288, fs.file-max>=131072)
SYSCTL_FILE="/etc/sysctl.d/99-sonarqube.conf"
echo "[Info] Configuring sysctl settings..."
cat > "$SYSCTL_FILE" <<EOF
vm.max_map_count=524288
fs.file-max=131072
EOF
sysctl -p "$SYSCTL_FILE"

# 3. Install Java 17, wget, unzip
echo "[Info] Installing OpenJDK 17, wget, unzip..."
apt-get install -y openjdk-17-jdk wget unzip gnupg2

# 4. Add PostgreSQL APT repo and install PostgreSQL 14
echo "[Info] Adding PostgreSQL APT repository..."
mkdir -p /usr/share/keyrings
wget -qO - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor > /usr/share/keyrings/pgdg-postgresql.gpg
echo "deb [signed-by=/usr/share/keyrings/pgdg-postgresql.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
    > /etc/apt/sources.list.d/pgdg.list
apt-get update -y
echo "[Info] Installing PostgreSQL 14..."
apt-get install -y postgresql-14

echo "[Info] Enabling and starting PostgreSQL..."
systemctl enable --now postgresql

# 5. Create PostgreSQL user and database for SonarQube (idempotent)
echo "[Info] Setting up PostgreSQL user and database..."
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname = '$DB_USER'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASS';"

sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER ENCODING 'UTF8' LC_COLLATE='en_US.utf8' LC_CTYPE='en_US.utf8' TEMPLATE=template0;"

sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"

# 6. Download and install SonarQube
SONAR_HOME="/opt/sonarqube"
if [ -d "$SONAR_HOME" ]; then
    echo "[Info] SonarQube directory already exists at $SONAR_HOME; skipping download."
else
    echo "[Info] Downloading SonarQube version $SONAR_VERSION..."
    cd /tmp
    wget -q "https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-$SONAR_VERSION.zip"
    echo "[Info] Extracting SonarQube..."
    unzip -q "sonarqube-$SONAR_VERSION.zip"
    mv "sonarqube-$SONAR_VERSION" "$SONAR_HOME"
    rm "sonarqube-$SONAR_VERSION.zip"
fi

# 7. Create sonar user and set ownership
echo "[Info] Creating sonar user and setting file permissions..."
if ! id -u sonarqube &>/dev/null; then
    adduser --system --no-create-home --group --disabled-login sonarqube
fi
chown -R sonarqube:sonarqube "$SONAR_HOME"

# 8. Configure sonar.properties for PostgreSQL
echo "[Info] Configuring sonar.properties..."
PROPS_FILE="$SONAR_HOME/conf/sonar.properties"
# Backup original properties file once
if [ ! -f "$PROPS_FILE.original" ]; then
    cp "$PROPS_FILE" "$PROPS_FILE.original"
fi

# Set JDBC settings (commented lines are un-commented/updated)
sed -i "s|^#\?sonar.jdbc.username=.*|sonar.jdbc.username=$DB_USER|" "$PROPS_FILE"
sed -i "s|^#\?sonar.jdbc.password=.*|sonar.jdbc.password=$DB_PASS|" "$PROPS_FILE"
sed -i "s|^#\?sonar.jdbc.url=.*|sonar.jdbc.url=jdbc:postgresql://localhost:5432/$DB_NAME|" "$PROPS_FILE"

# Ensure SonarQube listens on all interfaces (not just localhost)
if ! grep -q "^sonar.web.host=" "$PROPS_FILE"; then
    echo "sonar.web.host=0.0.0.0" >> "$PROPS_FILE"
else
    sed -i "s|^sonar.web.host=.*|sonar.web.host=0.0.0.0|" "$PROPS_FILE"
fi
# Default port is 9000; set explicitly for clarity
if ! grep -q "^sonar.web.port=" "$PROPS_FILE"; then
    echo "sonar.web.port=9000" >> "$PROPS_FILE"
else
    sed -i "s|^sonar.web.port=.*|sonar.web.port=9000|" "$PROPS_FILE"
fi

chown sonarqube:sonarqube "$PROPS_FILE"

# 9. Create systemd service for SonarQube
echo "[Info] Creating systemd service unit..."
SERVICE_FILE="/etc/systemd/system/sonarqube.service"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=SonarQube service
After=network.target

[Service]
Type=forking
ExecStart=$SONAR_HOME/bin/linux-x86-64/sonar.sh start
ExecStop=$SONAR_HOME/bin/linux-x86-64/sonar.sh stop
User=sonarqube
Group=sonarqube
PermissionsStartOnly=true
Restart=always
LimitNOFILE=131072
LimitNPROC=8192
TimeoutStartSec=5
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

# 10. Enable and start SonarQube
echo "[Info] Enabling and starting SonarQube service..."
systemctl enable --now sonarqube

# 11. UFW rule for port 9000
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
    echo "[Info] Adding UFW rule to allow port 9000..."
    ufw allow 9000/tcp || echo "[Info] UFW rule for port 9000 already exists."
else
    echo "[Info] UFW not active or not installed; skipping firewall configuration."
fi

echo "=== SonarQube Installation Completed Successfully ==="
