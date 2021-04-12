#!/bin/sh
 
# Adjust additional repositories
# apt-add-repository ppa:tista/adapta # Adapta theme repo

 
# Get the latest package lists
apt-get update && apt upgrade
 
# Get DEB files NO NEED
# wget https://prerelease.keybase.io/keybase_amd64.deb
 
# Install from Repo
apt-get install psad -y
apt-get install openssh-server -y
apt-get install unattended-upgrades -y

 
# Install DEB files
# dpkg -i keybase_amd64.deb
#apt --fix-broken install -y # Remediate possible issues
 
# Clean up DEB files
# rm -f keybase_amd64.deb
# Modify Configuration files
# sed 's/find/replace/' file
sed 's/'//Unattended-Upgrade::Automatic-Reboot "false";'/'Unattended-Upgrade::Automatic-Reboot "true";'/g' /etc/apt/apt.d.conf.d/50unattended-upgrades



# Final message
echo All applications have been installed, the script will now quit.
 
# Exit the script
exit 0
