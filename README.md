# TripwirePi
A Raspberry Pi based low-interaction SSH Honeypot built to be easy to install utilizing other open-source solutions.
 * Port Scan Attack Detector
 * Unattended-updates

This project was started thought the authors Computer Security Bachelor dissertation at the University of South Wales.

# Key principals for Deceptive capability
Do not pretend to be something you are not.
## Factors for logistical coorelation:
 * Placement and Network properties (IP address, subnet, MAC address, adjacent devices)
 * Allowed incomming traffic and enumeratable information (IPtables)
 * Adjacently viewable traffic (HTTP/HTTPS, Dest IP, URL's, Service Ports)


# Critical Configurations
## 1. Foreword
Do not directly copy the examples provided below as this would lead back to this project site revealing the device as a honeypot.
The examples are provided in order to guide the installing party to best possibly decieve an attacker into triggering the device, therefore the following configuration are vital to the devices functionality.

## 2. Hostname and deceptive logistics
A common indication of device purpose in any corporate network is matching the corporate naming scheme used by adjacent devices and naming the fake service provided by the honeypot. Say the honeypot is to be located in Bristol among the internal servers. 

The company naming scheme could be for example: 
 * LOCATION-OS-SERVICE##

Therefore an Active Directory Windows Server in Bristol could be: 
 * "BRI-WS-AD01"

In this example the honeypot is masqueraded as a “log collector” in the network.
The example name for this honeypot is: BRI-LX-LOG01

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
