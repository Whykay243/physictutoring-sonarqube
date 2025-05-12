#!/usr/bin/env bash
set -euxo pipefail

# 1. Variables & Random Passwords
TOMCAT_ADMIN_PASS=$(openssl rand -base64 18)
TOMCAT_MANAGER_PASS=$(openssl rand -base64 18)
XML_CONF=/etc/tomcat9/tomcat-users.xml
BACKUP_CONF=${XML_CONF}.orig

# 2. Update & Install OpenJDK 17 and Tomcat 9
apt-get update -y
DEBIAN_FRONTEND=noninteractive \
  apt-get install -y --no-install-recommends \
    openjdk-17-jdk tomcat9 tomcat9-admin ufw

# 3. Backup original tomcat-users.xml if not yet backed up
if [ ! -f "$BACKUP_CONF" ]; then
  cp "$XML_CONF" "$BACKUP_CONF"
fi

# 4. Generate a minimal tomcat-users.xml
cat > "$XML_CONF" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<tomcat-users>
  <!-- Admin GUI user -->
  <role rolename="admin-gui"/>
  <user username="admin" password="${TOMCAT_ADMIN_PASS}" roles="admin-gui"/>
  <!-- Manager script user -->
  <role rolename="manager-script"/>
  <user username="manager" password="${TOMCAT_MANAGER_PASS}" roles="manager-script"/>
</tomcat-users>
EOF

# 5. Secure file permissions
chown root:tomcat "$XML_CONF"
chmod 640 "$XML_CONF"

# 6. Enable & Start Tomcat
systemctl enable --now tomcat9

# 7. Configure UFW Firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH comment 'SSH access'
ufw allow 8080/tcp comment 'Tomcat Web UI'
ufw --force enable

# 8. Output credentials for retrieval
echo "Tomcat Admin UI -> http://$(hostname -I | awk '{print $1}'):8080/manager/html"
echo "  User: admin"
echo "  Password: ${TOMCAT_ADMIN_PASS}"
echo "Manager Script API credentials:"
echo "  User: manager"
echo "  Password: ${TOMCAT_MANAGER_PASS}"
