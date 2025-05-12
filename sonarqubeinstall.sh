#!/bin/bash

set -e

# Update and install required packages
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y wget unzip software-properties-common curl gnupg

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

# Get latest SonarQube release from GitHub with fallback
echo "Fetching latest SonarQube release from GitHub..."
LATEST_RELEASE=$(curl -s https://api.github.com/repos/SonarSource/sonarqube/releases/latest)

SONARQUBE_ZIP=$(echo "$LATEST_RELEASE" | grep "browser_download_url.*sonarqube-.*linux.*zip" | cut -d '"' -f 4)

# Fallback to known version if GitHub fails or returns empty
if [ -z "$SONARQUBE_ZIP" ]; then
    echo "GitHub API failed or rate limited. Falling back to SonarQube 10.4.1.88267."
    SONARQUBE_VERSION="10.4.1.88267"
    SONARQUBE_ZIP="https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONARQUBE_VERSION}.zip"
    SONARQUBE_FILE="sonarqube-${SONARQUBE_VERSION}.zip"
    SONARQUBE_DIR="sonarqube-${SONARQUBE_VERSION}"
else
    SONARQUBE_FILE=$(basename "$SONARQUBE_ZIP")
    SONARQUBE_DIR="${SONARQUBE_FILE%.zip}"
fi

echo "Downloading SonarQube: $SONARQUBE_FILE"
wget "$SONARQUBE_ZIP"
unzip "$SONARQUBE_FILE"
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
sudo useradd -r -s /bin/false sonarqube || true
sudo chown -R sonarqube:sonarqube /opt/sonarqube

sudo -u sonarqube bash -c "/opt/sonarqube/bin/linux-x86-64/sonar.sh start"

echo "SonarQube installation completed. Access it at http://<your-ec2-ip>:9000"
