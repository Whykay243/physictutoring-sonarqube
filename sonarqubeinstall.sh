#!/bin/bash

# Update system
echo "Updating system..."
sudo apt update -y && sudo apt upgrade -y

# Install Java 17 (required by recent SonarQube versions)
echo "Installing Java 17..."
if ! java -version &>/dev/null; then
    sudo apt install openjdk-17-jdk -y
else
    echo "Java 17 is already installed"
fi

# Install unzip (if not already installed)
echo "Installing unzip..."
if ! command -v unzip &>/dev/null; then
    sudo apt install unzip -y
else
    echo "Unzip is already installed"
fi

# Install PostgreSQL (if not already installed)
echo "Installing PostgreSQL..."
if ! command -v psql &>/dev/null; then
    sudo apt install postgresql postgresql-contrib -y
else
    echo "PostgreSQL is already installed"
fi

# Install Maven (if not already installed)
echo "Installing Maven..."
if ! command -v mvn &>/dev/null; then
    sudo apt install maven -y
else
    echo "Maven is already installed"
fi

# Start PostgreSQL service and enable on boot
echo "Starting PostgreSQL..."
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create SonarQube database and user if not exists
echo "Creating SonarQube database and user..."
DB_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='sonarqube'")
if [ "$DB_EXISTS" != "1" ]; then
    sudo -u postgres psql -c "CREATE DATABASE sonarqube;"
    sudo -u postgres psql -c "CREATE USER sonar WITH PASSWORD 'your_password';"
    sudo -u postgres psql -c "ALTER ROLE sonar SET client_encoding TO 'utf8';"
    sudo -u postgres psql -c "ALTER ROLE sonar SET default_transaction_isolation TO 'READ COMMITTED';"
    sudo -u postgres psql -c "ALTER ROLE sonar SET timezone TO 'UTC';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;"
else
    echo "Database 'sonarqube' already exists, skipping creation."
fi

USER_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='sonar'")
if [ "$USER_EXISTS" != "1" ]; then
    sudo -u postgres psql -c "CREATE USER sonar WITH PASSWORD 'your_password';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;"
else
    echo "User 'sonar' already exists, skipping creation."
fi

# Create SonarQube directory and download SonarQube
echo "Downloading and setting up SonarQube..."
cd /opt
if [ ! -f "sonarqube-10.4.1.88267.zip" ]; then
    sudo wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.4.1.88267.zip
else
    echo "SonarQube zip file already downloaded"
fi

# Extract SonarQube
sudo unzip -o sonarqube-10.4.1.88267.zip
sudo mv sonarqube-10.4.1.88267 sonarqube
sudo chown -R ubuntu:ubuntu /opt/sonarqube

# Set JAVA_HOME environment variable
echo "Setting JAVA_HOME environment variable..."
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# Start SonarQube service manually (to verify)
echo "Starting SonarQube..."
cd /opt/sonarqube/bin/linux-x86-64
./sonar.sh start
tail -f /opt/sonarqube/logs/sonar.log

# Check SonarQube status
echo "Checking SonarQube status..."
./sonar.sh status
