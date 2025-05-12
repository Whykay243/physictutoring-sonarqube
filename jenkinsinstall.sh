#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -x
set -euo pipefail

# 1. Update and install prerequisites
apt-get update -y
DEBIAN_FRONTEND=noninteractive \
  apt-get install -y --no-install-recommends \
    openjdk-17-jdk curl gnupg2 apt-transport-https ufw maven

# 2. Define JAVA_HOME for tools that need it
echo "export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which javac))))" > /etc/profile.d/java_home.sh
chmod +x /etc/profile.d/java_home.sh
source /etc/profile.d/java_home.sh

# 3. Add the Jenkins GPG key securely (no apt-key)
curl -fsSL https://pkg.jenkins.io/debian/jenkins.io-2023.key \
  | gpg --dearmor \
    --output /usr/share/keyrings/jenkins-keyring.gpg

# 4. Add Jenkins apt repository signed by our keyring
echo \
  "deb [signed-by=/usr/share/keyrings/jenkins-keyring.gpg] \
   https://pkg.jenkins.io/debian-stable binary/" \
  > /etc/apt/sources.list.d/jenkins.list

# 5. Install Jenkins
apt-get update -y
apt-get install -y jenkins

# 6. Enable and start Jenkins
systemctl enable jenkins
systemctl start jenkins

# 7. Wait for Jenkins to fully start
timeout=120
count=0
while ! curl -s http://localhost:8080/login >/dev/null; do
  ((count++)) || true
  if [ "$count" -ge "$timeout" ]; then
    echo "Jenkins did not start within $timeout seconds" >&2
    exit 1
  fi
  sleep 5
done

# 8. Retrieve initial admin password for easy access
ADMIN_PWD_FILE=/home/ubuntu/jenkins-password.txt
cp /var/lib/jenkins/secrets/initialAdminPassword "$ADMIN_PWD_FILE"
chown ubuntu:ubuntu "$ADMIN_PWD_FILE"
chmod 600 "$ADMIN_PWD_FILE"

# 9. Pre-install commonly used plugins via Jenkins CLI
JCLI=/usr/local/bin/jenkins-cli.jar
JENKINS_URL=http://localhost:8080
wget -q -O "$JCLI" "${JENKINS_URL}/jnlpJars/jenkins-cli.jar"
chmod +x "$JCLI"
PLUGINS=(git workflow-aggregator credentials-binding docker-workflow)
java -jar "$JCLI" -s "$JENKINS_URL" install-plugin "${PLUGINS[@]}" --restart

# 10. Harden UFW firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH comment 'SSH access'
ufw allow 8080 comment 'Jenkins UI'
ufw logging on
ufw --force enable

# 11. Cleanup apt cache
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "User data script completed successfully on $(date)"
