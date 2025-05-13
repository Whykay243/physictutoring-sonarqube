#!/bin/bash

# Log output
exec > /var/log/jenkins-install.log 2>&1
set -euxo pipefail

# Update system
apt-get update -y

# Install Java
apt-get install -y openjdk-17-jdk

# Add Jenkins GPG key and repository
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list

# Install Jenkins and Maven
apt-get update -y
apt-get install -y jenkins maven

# Create Groovy script to skip setup wizard and create admin user
mkdir -p /var/lib/jenkins/init.groovy.d

cat <<'EOF' > /var/lib/jenkins/init.groovy.d/basic-security.groovy
#!groovy

import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()

println "--> creating local user 'admin'"

def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("admin", "admin123")
instance.setSecurityRealm(hudsonRealm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

instance.save()
EOF

# Set correct permissions
chown -R jenkins:jenkins /var/lib/jenkins/init.groovy.d

# Start Jenkins
systemctl daemon-reexec
systemctl enable jenkins
systemctl restart jenkins
