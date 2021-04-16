#!/bin/sh
 
# Get the latest package lists and get dependencies
apt-get update && apt upgrade
apt install wget -y
apt install dialog -y

#Add dialog box for setting a hostname on the system
dialog --title "TripewirePi installer" --msgbox "TripewirePi is a device created with the intentions of being able to discover hackers in a local network.\\n\\nSuccessfully decieveing attackers is not easy. Therefore it is imperative to this device that you read the documentation and follow the guidelines for configuration.\\n\\nRead the guidelines at: https://github.com/Notorious-AFK/TripwirePi/blob/main/README.md" 15 90
clear
dialog --title "Set IP and Password" --msgbox "Please set a Static IP address and a unique password for this device prior to installation\\n\\nThe strength of this password is the only thing stopping the attackers from owning this device.\\n\\nKeep it secret, keep it safe.\\n\\nIf this has not been configured yet, cancel this installation using CTRL+C" 15 90
clear
dialog --title "Set system Hostname" --msgbox "Configure a new hostname for your device.\\n\\nMust be less than 28 characters\\n\\nProvide a name that matches the service hosted while adhereing to the naming scheme used by adjacent devices.\\nRead the guidelines for naming your device at: https://github.com/Notorious-AFK/TripwirePi/blob/main/README.md" 15 90
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
wget -P /tmp/ https://raw.githubusercontent.com/Notorious-AFK/TripwirePi/main/conf_files/msmtprc
wget -P /tmp/ https://raw.githubusercontent.com/Notorious-AFK/TripwirePi/main/conf_files/mailrc

# Replace existing configurations
cp /tmp/50unattended-upgrades /etc/apt/apt.conf.d/50unattended-upgrades
mkdir /etc/iptables
cp /tmp/rules.v4 /etc/iptables/rules.v4
cp /tmp/ssh_config /etc/ssh/ssh_config
cp /tmp/mailrc /etc/mailrc
# MSMTPRC IS COPIED LATER DUE TO CONFIGURATIONAL CHANGES

echo CONFIGURATION FILES TRANSFERRED

# Modify Configuration files
# sed 's/find/replace/' file

# Add Alert email address and SMTP App password
# https://www.alanbonnici.com/2020/11/howto-send-email-from-google-from.html

# USER INPUT EMAIL DETAILS
dialog --title "Set Alert Email" --msgbox "The system needs an SMTP email address to send from.\\nThis installer only supports SMTP gmail via MSMTP.\\n\\n\\nTo configure a non-gmail email read the Email Configuration at: https://github.com/Notorious-AFK/TripwirePi/blob/main/README.md\\n\\n\\nTo set up a Gmail account with SMTP follow these instructions: https://support.google.com/mail/answer/7126229?hl=en" 20 80
clear
dialog --title "Alert Email Address" --inputbox "Enter your SMTP Enabled Gmail address:" 20 40 2>/tmp/gmail.txt
clear
dialog --title "Alert Email Address" --inputbox "Enter your Gmail address before the @ sign\\n\\nExample input: company.name \\nFull gmail is: company.name@gmail.com" 20 60 2>/tmp/shortmail.txt
clear
dialog --title "Alert Email Address" --inputbox "Enter your Gmail App password:" 20 40 2>/tmp/passmail.txt
clear

#EMAIL CONFIG REPLACEMENTS
replg=`cat /tmp/gmail.txt`
replu=`cat /tmp/shortmail.txt`
replp=`cat /tmp/passmail.txt`
replh=`cat /tmp/hostname.txt`

sed -i "s/BEFORETHEAT/${replu}/g" /tmp/msmtprc
sed -i "s/EMAILAPPPASSWORD/${replp}/g" /tmp/msmtprc
sed -i "s/YOUR@GMAIL/${replg}/g" /tmp/msmtprc     
sed -i "s/REPLACE_EMAIL/${replg}/g" /tmp/psad.conf
sed -i "s/REPLACE_HOSTNAME/${replh}/g" /tmp/psad.conf

echo Email Config Replacements Completed
cp /tmp/msmtprc /etc/msmtprc
cp /tmp/psad.conf /etc/psad/psad.conf

echo Copy Complete Cleaning up Temp
rm /tmp/gmail.txt
rm /tmp/shortmail.txt
rm /tmp/passmail.txt
rm /tmp/msmtprc

# Fix rights on msmtp
chown root:msmtp /etc/msmtprc
chmod 640 /etc/msmtprc
touch /var/log/msmtp
chmod 660 /var/log/msmtp
echo smtp.gmail.com > /tmp/mailname
cp /tmp/mailname /etc/mailname

# Modify repo lists to have HTTPS
sed 's/http/https/g' /etc/apt/sources.list > /tmp/sources.list
sed 's/http/https/g' /etc/apt/sources.list.d/raspi.list > /tmp/raspi.list
cp /tmp/sources.list /etc/apt/sources.list
cp /tmp/raspi.list /etc/apt/sources.list.d/raspi.list

# Diable IPv6 and Apply IPtables and make permanent
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
apt-get install iptables-persistent -y
iptables-restore < /etc/iptables/rules.v4

# Add Custon PSAD rule to Signatures
cp /etc/psad/signatures /tmp/signatures
echo 'alert tcp $EXTERNAL_NET any -> $HOME_NET 22 (msg:"SSH Connection"; reference:url,https://github.com/Notorious-AFK/TripwirePi; classtype:tripwirepi-alert; psad_id:106484; psad_dl:5;)' >> /tmp/signatures
cp /tmp/signatures /etc/psad/signatures

# Finalizing installation
dialog --title "Testing Email" --msgbox "To send a test email try the following:\\necho \"test\" | mail -s \"test\" your@email.com." 10 50
clear
cp /tmp/hostname.txt /etc/hostname
dialog --title "Installation Complete" --msgbox "Services have been installed.\\nPlease restart the system to get the new hostname." 10 40
clear

#SERVICE RESTARTS
echo Attempting to restart PSAD service. Might timeout.
systemctl restart psad.service

# Final message
echo All applications have been installed, the script will now quit.

# Exit the script
exit 0
