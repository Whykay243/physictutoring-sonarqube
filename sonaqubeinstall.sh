#!/bin/bash
set -euo pipefail

# 0. RAM check
if [ "$(free -m | awk '/^Mem:/{print $2}')" -lt 2000 ]; then
  echo "⚠️  SonarQube recommends ≥2 GB RAM. Continuing anyway…"
fi

echo "🔧 Backing up & tuning sysctl for SonarQube/Elasticsearch…"
sudo cp /etc/sysctl.conf /etc/sysctl.conf.bak.$(date +%F_%T)

# Ensure each setting only appears once
for setting in \
  "vm.max_map_count=262144" \
  "fs.file-max=65536" \
  "ulimit -n 65536" \
  "ulimit -u 4096"
do
  grep -qF "$setting" /etc/sysctl.conf || echo "$setting" | sudo tee -a /etc/sysctl.conf
done

sudo sysctl -p

echo "📥 Updating apt and installing prerequisites…"
sudo apt update -y
sudo apt install -y openjdk-17-jdk wget unzip ca-certificates lsb-release

echo "📦 Installing PostgreSQL…"
# Import the repo’s signing key and add its repo with signed-by
PG_KEYRING=/usr/share/keyrings/pgdg-archive-keyring.gpg
sudo wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc \
  | gpg --dearmor | sudo tee "$PG_KEYRING" >/dev/null

echo "deb [signed-by=$PG_KEYRING] http://apt.postgresql.org/pub/repos/apt \
  $(lsb_release -cs)-pgdg main" \
  | sudo tee /etc/apt/sources.list.d/pgdg.list

sudo apt update -y
sudo apt install -y postgresql-14 postgresql-client-14

echo "🗄️  Configuring PostgreSQL for SonarQube…"
sudo systemctl enable --now postgresql
sudo -u postgres psql <<EOF
CREATE USER sonar WITH ENCRYPTED PASSWORD 'sonarpass';
CREATE DATABASE sonarqube OWNER sonar ENCODING 'UTF8' LC_COLLATE='en_US.utf8' LC_CTYPE='en_US.utf8';
GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;
EOF

echo "👤 Creating SonarQube system user…"
sudo useradd -m -d /opt/sonarqube -U -s /bin/bash sonarqube || true

SONAR_VER="10.3.0.82913"
SONAR_ZIP="sonarqube-${SONAR_VER}.zip"
SONAR_URL="https://binaries.sonarsource.com/Distribution/sonarqube/${SONAR_ZIP}"

echo "⬇️ Downloading SonarQube ${SONAR_VER}…"
cd /tmp
wget -q "$SONAR_URL"
unzip -q "$SONAR_ZIP"
sudo mv "sonarqube-${SONAR_VER}" /opt/sonarqube

echo "⚙️  Configuring JDBC settings…"
sudo tee -a /opt/sonarqube/conf/sonar.properties >/dev/null <<EOF

#— PostgreSQL settings
sonar.jdbc.username=sonar
sonar.jdbc.password=sonarpass
sonar.jdbc.url=jdbc:postgresql://localhost:5432/sonarqube
EOF

echo "🔐 Setting ownership and permissions…"
sudo chown -R sonarqube:sonarqube /opt/sonarqube
sudo chmod -R 755 /opt/sonarqube

echo "🧩 Creating systemd service unit…"
sudo tee /etc/systemd/system/sonarqube.service >/dev/null <<EOF
[Unit]
Description=SonarQube service
After=network.target postgresql.service

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonarqube
Group=sonarqube
Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

echo "🚀 Enabling & starting SonarQube…"
sudo systemctl daemon-reload
sudo systemctl enable --now sonarqube

# Optionally open UFW port
if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
  echo "🔐 Allowing TCP/9000 in UFW…"
  sudo ufw allow 9000/tcp
fi

echo "✅ Done! Access SonarQube at: http://$(hostname -I | awk '{print $1}'):9000"
