#!/bin/sh

# Create a Script to Automate the Installation of Apache Tomcat on the EC2 Instance
sudo apt update -y

# Install Java SDK 11
sudo apt install openjdk-11-jdk -y

# Install Tomcat and dependencies
sudo apt-get install tomcat9 tomcat9-docs tomcat9-admin -y

# Assign roles and credentials for admin & user access
# Adding the roles and users directly to tomcat-users.xml
echo "Configuring Tomcat users and roles..."

sudo tee /var/lib/tomcat9/conf/tomcat-users.xml > /dev/null <<EOF
<tomcat-users>
  <role rolename="manager-script"/>
  <role rolename="admin-gui"/>
  <role rolename="manager-gui"/>
  <user username="tomcat" password="strongpassword" roles="manager-script"/>
  <user username="admin" password="strongpassword" roles="admin-gui,manager-gui"/>
</tomcat-users>
EOF

# Remove any unnecessary or pre-existing configurations from tomcat-users.xml
sudo sed -i '56d' /var/lib/tomcat9/conf/tomcat-users.xml

# Copy admin files to webapps (to enable manager and admin GUI)
sudo cp -r /usr/share/tomcat9-admin/* /var/lib/tomcat9/webapps/ -v

# Set proper permissions to avoid security issues
sudo chmod 777 /var/lib/tomcat9/conf/tomcat-users.xml

# Clear screen for better readability
echo 'Clearing screen...' && sleep 5
clear

# Notify user that installation is complete
echo 'Tomcat is installed and configured with Java 17.'

# Restart Tomcat to apply changes
echo 'Restarting Tomcat...'
sudo systemctl restart tomcat9

# Confirm Tomcat is running
sudo systemctl status tomcat9
