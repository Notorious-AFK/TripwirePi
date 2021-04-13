#!/bin/sh
 
# Get the latest package lists and get dependencies
apt-get update && apt upgrade
apt install wget -y
apt install dialog -y

#Add dialog box for setting a hostname on the system
dialog --title "Set system Hostname" --msgbox "Configure a new hostname for your device.\\nMust be less than 28 characters\\n\\nProvide a name that matches the service hosted while adhereing to the naming scheme used by adjacent devices.\\nRead the guidelines for naming your device at: https://github.com/Notorious-AFK/TripwirePi/blob/main/README.md" 25 90
clear
dialog --title "New Hostname" --inputbox "Enter new hostname reflecting company device branding:" 20 40 2>/tmp/hostname.txt
clear


# Install from Repo
apt-get install psad -y
apt-get install openssh-server -y
apt-get install unattended-upgrades -y
apt-get install msmtp -y
apt-get install msmtp-mta -y

# Download configuration files
wget -P /tmp/ https://raw.githubusercontent.com/Notorious-AFK/TripwirePi/main/conf_files/50unattended-upgrades
wget -P /tmp/ https://raw.githubusercontent.com/Notorious-AFK/TripwirePi/main/conf_files/rules.v4
wget -P /tmp/ https://raw.githubusercontent.com/Notorious-AFK/TripwirePi/main/conf_files/psad.conf
wget -P /tmp/ https://raw.githubusercontent.com/Notorious-AFK/TripwirePi/main/conf_files/ssh_config

# Replace existing configurations
cp /tmp/50unattended-upgrades /etc/apt/apt.conf.d/50unattended-upgrades
mkdir /etc/iptables
cp /tmp/rules.v4 /etc/iptables/rules.v4
cp /tmp/psad.conf /etc/psad/psad.conf
cp /tmp/ssh_config /etc/ssh/ssh_config

echo CONFIGURATION FILES TRANSFERRED

# Modify Configuration files
# sed 's/find/replace/' file

# Add Alert email address and SMTP App password
# https://www.alanbonnici.com/2020/11/howto-send-email-from-google-from.html

# USER INPUT EMAIL DETAILS
dialog --title "Set Alert Email" --msgbox "The system needs an SMTP email address to send alerts to.\\nThis installer only supports SMTP gmail via MSMTP.\\nTo configure a non-gmail email read the "Email Configuration" at: https://github.com/Notorious-AFK/TripwirePi/blob/main/README.md\\n\\n\\nTo set up a Gmail account with SMTP follow these instructions: https://support.google.com/mail/answer/7126229?hl=en" 25 90
clear
dialog --title "Alert Email Address" --inputbox "Enter your SMTP Enabled Gmail address:" 20 40 2>/tmp/gmail.txt
clear
dialog --title "Alert Email Address" --inputbox "Enter your SMTP Enabled Gmail address:" 20 40 2>/tmp/gmail.txt
clear
dialog --title "Alert Email Address" --inputbox "Enter your SMTP Enabled Gmail address:" 20 40 2>/tmp/gmail.txt
clear


# Modify repo lists to have HTTPS
sed 's/http/https/g' /etc/apt/sources.list > /tmp/sources.list
sed 's/http/https/g' /etc/apt/sources.list.d/raspi.list > /tmp/raspi.list
cp /tmp/sources.list /etc/apt/sources.list
cp /tmp/raspi.list /etc/apt/sources.list.d/raspi.list

# Apply IPtables and make permanent
apt-get install iptables-persistent -y
iptables-restore < /etc/iptables/rules.v4

# Finalizing installation
cp /tmp/hostname.txt /etc/hostname
dialog --title "Installation Complete" --msgbox "Services have been installed.\\nPlease restart the system to get the new hostname." 10 20
clear

#ADD SERVICE RESTARTS

# Final message
echo All applications have been installed, the script will now quit.
 
# Exit the script
exit 0
