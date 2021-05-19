# TripwirePi
A Raspberry Pi based low-interaction SSH Honeypot built to be easy to install utilizing open-source solutions.
 * Port Scan Attack Detector
 * Unattended-updates
 * IPtables
 * MSMTA
 * Raspberry Pi

This project was started through the authors Computer Security Bachelor dissertation at the University of South Wales.

# Installation
```
wget https://raw.githubusercontent.com/Notorious-AFK/TripwirePi/main/install.sh
sudo chmod +x install.sh
sudo ./install.sh
```
Read the sections below prior to installing!

# Disclaimer
Tripwire Pi is in no way a fully-fledged security solution and does not take any responsibility for any events related to the product or its usage. This is an open-source project with no claims of guaranteed success or attacker discovery. The project is “best-effort” following key concepts towards improving deception while maintaining security.

# Critical Configurations
## 1. Foreword
Do not directly copy the examples provided below as this could reveal the device as a honeypot.
The examples are provided in order to guide the installing party to best possibly decieve an attacker into triggering the honeypot, therefore the following configuration are vital to the devices functionality.

## 2. Requirements before installing
 * Installed Raspbian OS on device
   * with or without GUI
 * Changed user password to a unique and secure one
   * e.g. 16 characters (More, not less!)
 * Set a static IP address
 * Created Gmail account with SMTP enabled
   * MFA enabled with Application password recommended

## 3. Hostname and deceptive logistics
A common indication of device purpose in any network is matching the naming scheme used by adjacent devices while considering the service provided by the honeypot. Use your own naming scheme.

Naming scheme example: 
 * LOCATION-OS-SERVICE##

Thereby a Log Collector service on a linux machine in Bristol could be: 
 * "BRI-LX-LOG01"

When configuring any aspect of a honeypot it is important to keep in mind the implications this creates, perform tests and review externally for the best possibility of deception.
 * What services can be seen externally?
 * What network traffic is the device generating?
   * HTTP/HTTPS, URL's
   * Destination IP’s
 * Does the externally availbable information match logistically?
   * SSH on a Log Collector linux machine serving as a backend service port
     * Deceptive
   * SSH on a file server fetching updates from raspbian.org?
     * Poor Deception
 * Is the device and its service in a part of the network that corelates with its purpose?
   * SSH log server in a server VLAN
     * Deceptive
   * SSH log server on a guest Wifi VLAN
     * Poor Deception

## 4. Post installation testing
 * psad -S
 * iptables -L
 * Send test email: echo "test" | mail -s "test" your@email.com.
 * Connect to SSH from adjacent machine and check for alerts

## 5. Key principals for Deceptive capability
Do not pretend to be something you are not.
Device should look to be serving an actual purpose in the network.
### Factors for logistical coorelation:
 * Placement and Network properties (IP address, subnet, MAC address, adjacent devices)
 * Allowed incomming traffic and enumeratable information (IPtables)
 * Adjacently viewable traffic (HTTP/HTTPS, Dest IP, URL's, Service Ports)


## 6. Mitigating false positives
![Alert mitigation sequence (1)](https://user-images.githubusercontent.com/57632518/115236940-409b2e00-a11c-11eb-9e21-193506d35f35.png)
