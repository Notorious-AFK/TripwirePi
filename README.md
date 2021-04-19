# TripwirePi
A Raspberry Pi based low-interaction SSH Honeypot built to be easy to install utilizing other open-source solutions.
 * Port Scan Attack Detector
 * Unattended-updates
 * IPtables
 * MSMTA
 * Raspberry Pi

This project was started thought the authors Computer Security Bachelor dissertation at the University of South Wales.

# Installation
Read the sections below prior to installing!
```
wget https://raw.githubusercontent.com/Notorious-AFK/TripwirePi/main/install.sh
sudo chmod +x install.sh
sudo ./install.sh
```

# Key principals for Deceptive capability
Do not pretend to be something you are not.
## Factors for logistical coorelation:
 * Placement and Network properties (IP address, subnet, MAC address, adjacent devices)
 * Allowed incomming traffic and enumeratable information (IPtables)
 * Adjacently viewable traffic (HTTP/HTTPS, Dest IP, URL's, Service Ports)

# Disclaimer
Tripwire Pi is in no way a fully-fledged security solution and does not take any responsibility for any events related to the product or its usage. This is an open-source project with no claims of guaranteed success or attacker discovery. The project is “best-effort” following key concepts towards improving deception while maintaining security.

# Critical Configurations
## 1. Foreword
Do not directly copy the examples provided below as this would lead back to this project site revealing the device as a honeypot.
The examples are provided in order to guide the installing party to best possibly decieve an attacker into triggering the device, therefore the following configuration are vital to the devices functionality.

## 2. Requirements before installing
 * Installed Raspbian OS on device
   * with or without GUI
 * Changed user password to a unique and secure one
 * Set a static IP address
 * Gmail account with SMTP enabled
   * MFA enabled with Application password recommended

## 3. Hostname and deceptive logistics
A common indication of device purpose in any corporate network is matching the corporate naming scheme used by adjacent devices and naming the fake service provided by the honeypot. Use your own corporate naming scheme.

The naming scheme could be for example: 
 * LOCATION-OS-SERVICE##

Thereby an Active Directory Windows Server in Bristol could be: 
 * "BRI-WS-AD01"

In this example the honeypot is masqueraded as a “log collector” in the network.
**The example name for this honeypot is: BRI-LX-LOG01

When configuring the hostname it is important to keep in mind the implications this creates and perform tests for the best possibility of deception.
 * What services can be seen externally?
 * What network traffic is the device generating?
   * HTTP/HTTPS, URL's
   * Destination IP’s
 * Does the externally availbable information make sense logistically?
   * SSH on a Log Collector linux machine serving as a backend service port
     * Deceptive
   * SSH on a file server fetching updates from raspbian.org?
     * Poor Deception
   * Is the device and its supplied service placed in a part of the network that corelates with its purpose?
     * SSH log server in a server VLAN
       * Deceptive
     * SSH log server on a guest Wifi VLAN
       * Poor Deception

## 4. Post installation testing
 * psad -S
 * iptables -L
 * Send test email: echo "test" | mail -s "test" your@email.com.
 * Connect to SSH from adjacent machine and check for alerts
