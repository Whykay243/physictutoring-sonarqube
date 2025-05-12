#!/bin/bash

# Update and install necessary packages
apt-get update
apt-get install -y unzip software-properties-common wget default-jdk postgresql postgresql-contrib

# Configure PostgreSQL
su - postgres -c "psql <<EOF
CREATE USER sonarqube WITH PASSWORD 'kamisama123';
CREATE DATABASE sonarqube OWNER sonarqube;
GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonarqube;
\\q
EOF"

# Download and install SonarQube
mkdir -p /downloads/sonarqube
cd /downloads/sonarqube
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-25.1.0.102122.zip
unzip sonarqube-25.1.0.102122.zip
mv sonarqube-25.1.0 /opt/sonarqube

# Create SonarQube user and set permissions
adduser --system --no-create-home --group --disabled-login sonarqube
chown -R sonarqube:sonarqube /opt/sonarqube

# Configure sonar.sh
sed -i 's/#RUN_AS_USER=sonar/RUN_AS_USER=sonarqube/' /opt/sonarqube/bin/linux-x86-64/sonar.sh

# Configure sonar.properties
cat <<EOF > /opt/sonarqube/conf/sonar.properties
sonar.jdbc.username=sonarqube
sonar.jdbc.password=kamisama123
sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube
sonar.web.javaAdditionalOpts=-server
sonar.web.host=0.0.0.0
EOF

# Create and configure 99-sonarqube.conf
cat <<EOF > /etc/security/limits.d/99-sonarqube.conf
sonarqube - nofile 65536
sonarqube - nproc 4096
EOF

# Edit sysctl.conf
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
echo "fs.file-max=65536" >> /etc/sysctl.conf
sysctl -p

# Start SonarQube
/opt/sonarqube/bin/linux-x86-64/sonar.sh start