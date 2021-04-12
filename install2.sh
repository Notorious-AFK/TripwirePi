#!/bin/sh
 
# Adjust additional repositories
# apt-add-repository ppa:tista/adapta # Adapta theme repo

 
# Get the latest package lists and get dependencies
apt-get update && apt upgrade
apt install wget
 
# Get DEB files NO NEED
# wget https://prerelease.keybase.io/keybase_amd64.deb
 
# Install from Repo
apt-get install psad -y
apt-get install openssh-server -y
apt-get install unattended-upgrades -y

# Download and replace configuration files
mkdir tripwirepi/
cd tripwirepi
wget https://raw.githubusercontent.com/Notorious-AFK/TripwirePi/main/conf_files/50unattended-upgrades
wget https://raw.githubusercontent.com/Notorious-AFK/TripwirePi/main/conf_files/rules.v4
wget https://raw.githubusercontent.com/Notorious-AFK/TripwirePi/main/conf_files/psad.conf
cp 50unattended-upgrades /etc/apt/apt.conf.d/50unattended-upgrades
mkdir /etc/iptables
cp rules.v4 /etc/iptables/rules.v4
cp psad.conf /etc/psad/psad.conf

echo CONFIGURATION FILES TRANSFERRED
# Install DEB files
# dpkg -i keybase_amd64.deb
#apt --fix-broken install -y # Remediate possible issues

# Clean up DEB files
# rm -f keybase_amd64.deb
# Modify Configuration files
# sed 's/find/replace/' file


# Apply IPtables and make permanent
apt-get install iptables-persistent -y
iptables-restore < /etc/iptables/rules.v4
# Final message
echo All applications have been installed, the script will now quit.
 
# Exit the script
exit 0
