#!/bin/bash
set -e

# Update system
sudo yum update -y

# Install Java 17 (Amazon Corretto)
sudo yum install -y java-17-amazon-corretto

# Create a sonarqube user
sudo useradd -m -d /opt/sonarqube -r -s /bin/bash sonarqube

# Install PostgreSQL 13
sudo amazon-linux-extras enable postgresql13
sudo yum install -y postgresql postgresql-server
sudo postgresql-setup initdb
sudo systemctl enable --now postgresql

# Configure PostgreSQL
sudo -u postgres psql -c "CREATE USER sonar WITH ENCRYPTED PASSWORD 'sonar';"
sudo -u postgres psql -c "CREATE DATABASE sonarqube OWNER sonar;"

# Allow password auth in PostgreSQL
sudo sed -i "s/^host.*127.0.0.1\/32.*$/host    all             all             127.0.0.1\/32            md5/" /var/lib/pgsql/data/pg_hba.conf
sudo systemctl restart postgresql

# Download and extract SonarQube
SONAR_VERSION=10.4.1.88267
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-$SONAR_VERSION.zip
sudo yum install -y unzip
unzip sonarqube-$SONAR_VERSION.zip
sudo mv sonarqube-$SONAR_VERSION/* /opt/sonarqube/
sudo chown -R sonarqube:sonarqube /opt/sonarqube

# Configure SonarQube to connect to PostgreSQL
sudo sed -i '/^#sonar.jdbc.username=/c\sonar.jdbc.username=sonar' /opt/sonarqube/conf/sonar.properties
sudo sed -i '/^#sonar.jdbc.password=/c\sonar.jdbc.password=sonar' /opt/sonarqube/conf/sonar.properties
sudo sed -i '/^#sonar.jdbc.url=jdbc:postgresql/c\sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube' /opt/sonarqube/conf/sonar.properties

# Create a systemd service
sudo bash -c 'cat > /etc/systemd/system/sonarqube.service <<EOF
[Unit]
Description=SonarQube service
After=syslog.target network.target postgresql.service

[Service]
Type=simple
User=sonarqube
Group=sonarqube
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
Restart=always
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF'

# Start SonarQube
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable sonarqube
sudo systemctl start sonarqube
