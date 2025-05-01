#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -x

# Update system and install Java
sudo apt update -y
sudo apt install -y openjdk-17-jdk curl gnupg2

# Add Jenkins GPG key the correct way
curl -fsSL https://pkg.jenkins.io/debian/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null

# Add Jenkins apt repo with signed-by reference
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

# Update again and install Jenkins
sudo apt update -y
sudo apt install -y jenkins

# Enable and start Jenkins
sudo systemctl enable jenkins
sudo systemctl start jenkins

# Optional: Install Maven
sudo apt install -y maven

# Open firewall ports
sudo ufw allow 8080
sudo ufw allow OpenSSH
sudo ufw --force enable