#!/bin/bash
set -e

# Update system packages
sudo apt-get update -y
sudo apt-get upgrade -y

# Install Java 17 (required for latest SonarQube)
sudo apt-get install -y openjdk-17-jdk unzip wget

# Create SonarQube user
sudo useradd -m -d /opt/sonarqube -r -s /bin/bash sonarqube

# Install and configure PostgreSQL
sudo apt-get install -y postgresql postgresql-contrib

# Set PostgreSQL password and create DB
sudo -u postgres psql -c "CREATE USER sonar WITH ENCRYPTED PASSWORD 'sonar';"
sudo -u postgres psql -c "CREATE DATABASE sonarqube OWNER sonar;"

# Enable password auth in pg_hba.conf
sudo sed -i "s/^local\s\+all\s\+postgres\s\+peer/local all postgres md5/" /etc/postgresql/*/main/pg_hba.conf
sudo sed -i "s/^local\s\+all\s\+all\s\+peer/local all all md5/" /etc/postgresql/*/main/pg_hba.conf
echo "listen_addresses = '*'" | sudo tee -a /etc/postgresql/*/main/postgresql.conf
sudo systemctl restart postgresql

# Download and set up SonarQube
SONAR_VERSION=10.4.1.88267
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONAR_VERSION}.zip
unzip sonarqube-${SONAR_VERSION}.zip
sudo mv sonarqube-${SONAR_VERSION}/* /opt/sonarqube/
sudo chown -R sonarqube:sonarqube /opt/sonarqube

# Configure SonarQube to connect to PostgreSQL
sudo sed -i "s|#sonar.jdbc.username=.*|sonar.jdbc.username=sonar|" /opt/sonarqube/conf/sonar.properties
sudo sed -i "s|#sonar.jdbc.password=.*|sonar.jdbc.password=sonar|" /opt/sonarqube/conf/sonar.properties
sudo sed -i "s|#sonar.jdbc.url=jdbc:postgresql.*|sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube|" /opt/sonarqube/conf/sonar.properties

# Set system limits for SonarQube
echo 'sonarqube   -   nofile   65536' | sudo tee -a /etc/security/limits.conf
echo 'sonarqube   -   nproc    4096' | sudo tee -a /etc/security/limits.conf

# Create systemd service
sudo bash -c 'cat <<EOF > /etc/systemd/system/sonarqube.service
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
EOF'

# Enable and start the SonarQube service
sudo systemctl daemon-reload
sudo systemctl enable sonarqube
sudo systemctl start sonarqube
