#!/bin/bash
set -e

echo "🔧 Starting SonarQube installation..."

# 0. Ensure we have at least 2 GB RAM available
if [ "$(free -m | awk '/^Mem:/{print $2}')" -lt 2000 ]; then
  echo "⚠️ Warning: SonarQube recommends ≥2 GB RAM. Proceeding anyway."
fi

# 1. Update OS
sudo apt update && sudo apt upgrade -y

# 2. Install prerequisites
echo "📦 Installing Java (OpenJDK 17), wget, unzip..."
sudo apt install -y openjdk-17-jdk wget unzip

# 3. Increase vm.max_map_count
echo "🔧 Configuring vm.max_map_count..."
sudo sysctl -w vm.max_map_count=262144
# persist across reboots
if ! grep -q vm.max_map_count /etc/sysctl.conf; then
  echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
fi

# 4. Create sonarqube user
echo "👤 Creating sonarqube user..."
sudo useradd -m -d /opt/sonarqube -U -s /bin/bash sonarqube

# 5. Download & install SonarQube
SONAR_VERSION="10.3.0.82913"
echo "⬇️ Downloading SonarQube ${SONAR_VERSION}..."
cd /tmp
wget -q https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONAR_VERSION}.zip
unzip -q sonarqube-${SONAR_VERSION}.zip
sudo mv sonarqube-${SONAR_VERSION}/* /opt/sonarqube/

# 6. Permissions
echo "🔐 Setting ownership and permissions..."
sudo chown -R sonarqube:sonarqube /opt/sonarqube
sudo chmod -R 755            /opt/sonarqube

# 7. systemd service
echo "🧩 Creating SonarQube systemd unit..."
sudo tee /etc/systemd/system/sonarqube.service > /dev/null <<EOF
[Unit]
Description=SonarQube service
After=network.target

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

# 8. Start & enable
echo "🚀 Enabling & starting SonarQube..."
sudo systemctl daemon-reload
sudo systemctl enable sonarqube
sudo systemctl start sonarqube

# 9. UFW firewall (if active)
if sudo ufw status | grep -q "Status: active"; then
  echo "🔐 Allowing port 9000 through UFW..."
  sudo ufw allow 9000/tcp
fi

echo "✅ SonarQube installed! Visit: http://\$(hostname -I | awk '{print \$1}'):9000"
