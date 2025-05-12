#!/bin/bash

set -e

# Update and install required packages
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y wget unzip software-properties-common

# Install Java 17 (required by SonarQube 10.4+)
sudo apt-get install -y openjdk-17-jdk
echo "JAVA installed: $(java -version)"

# Set JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
echo "export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64" | sudo tee -a /etc/profile
source /etc/profile

# Install Maven
sudo apt-get install -y maven
echo "Maven installed: $(mvn -version)"

# Install PostgreSQL
sudo apt-get install -y postgresql postgresql-contrib
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Configure PostgreSQL for SonarQube
sudo -u postgres psql <<EOF
CREATE USER sonarqube WITH ENCRYPTED PASSWORD 'sonarqube';
CREATE DATABASE sonarqube OWNER sonarqube;
ALTER USER sonarqube CREATEDB;
EOF

# Download and extract SonarQube
SONARQUBE_VERSION="10.4.1.88267"
SONARQUBE_ZIP="sonarqube-$SONARQUBE_VERSION.zip"
SONARQUBE_DIR="sonarqube-$SONARQUBE_VERSION"
SONARQUBE_URL="https://binaries.sonarsource.com/Distribution/sonarqube/$SONARQUBE_ZIP"

wget "$SONARQUBE_URL"
unzip "$SONARQUBE_ZIP"
sudo mv "$SONARQUBE_DIR" /opt/sonarqube

# Update sonar.properties
SONAR_PROPERTIES="/opt/sonarqube/conf/sonar.properties"
sudo cp "$SONAR_PROPERTIES" "$SONAR_PROPERTIES.bak"

sudo sed -i 's/#sonar.jdbc.username=/sonar.jdbc.username=sonarqube/' "$SONAR_PROPERTIES"
sudo sed -i 's/#sonar.jdbc.password=/sonar.jdbc.password=sonarqube/' "$SONAR_PROPERTIES"
sudo sed -i 's|#sonar.jdbc.url=jdbc:postgresql.*|sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube|' "$SONAR_PROPERTIES"
sudo sed -i 's/#sonar.web.port=9000/sonar.web.port=9000/' "$SONAR_PROPERTIES"

# Adjust Linux settings for SonarQube
sudo sysctl -w vm.max_map_count=262144
sudo sysctl -w fs.file-max=65536
ulimit -n 65536
ulimit -u 4096

# Set permissions and start SonarQube
sudo useradd -r -s /bin/false sonarqube
sudo chown -R sonarqube:sonarqube /opt/sonarqube

sudo -u sonarqube bash -c "/opt/sonarqube/bin/linux-x86-64/sonar.sh start"

echo "SonarQube installation completed. Access it at http://<your-ec2-ip>:9000"
