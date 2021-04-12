# Completely stolen from the PiVPN project due to its fantastic installer.
# All credit to PiVPN, its creators and contributors.
# https://pivpn.io
# Heavily modified for own purpose of installing and guiding the configuration of this project.

#!/usr/bin/env bash
# Install with this command (from your Pi):
#
# curl -L https://LINK TO THIS RAW CONTENT
# Make sure you have `curl` installed
######## SCRIPT ########

# Find the rows and columns. Will default to 80x24 if it can not be detected.
screen_size=$(stty size 2>/dev/null || echo 24 80)
rows=$(echo "$screen_size" | awk '{print $1}')
columns=$(echo "$screen_size" | awk '{print $2}')

# Divide by two so the dialogs take up half of the screen, which looks nice.
r=$(( rows / 2 ))
c=$(( columns / 2 ))
# Unless the screen is tiny
r=$(( r < 20 ? 20 : r ))
c=$(( c < 70 ? 70 : c ))

# Override localization settings so the output is in English language.
export LC_ALL=C

main(){

	######## FIRST CHECK ########
	# Must be root to install
	echo ":::"
	if [[ $EUID -eq 0 ]];then
		echo "::: You are root."
	else
		echo "::: sudo will be used for the install."
		# Check if it is actually installed
		# If it isn't, exit because the install cannot complete
		if [[ $(dpkg-query -s sudo) ]];then
			export SUDO="sudo"
			export SUDOE="sudo -E"
		else
			echo "::: Please install sudo or run this as root."
			exit 1
		fi
	fi

	# Check arguments for the undocumented flags
	for ((i=1; i <= "$#"; i++)); do
		j="$((i+1))"
		case "${!i}" in
			"--skip-space-check"        ) skipSpaceCheck=true;;
			"--unattended"              ) runUnattended=true; unattendedConfig="${!j}";;
			"--reconfigure"             ) reconfigure=true;;
			"--show-unsupported-nics"   ) showUnsupportedNICs=true;;
		esac
	done

	if [[ "${runUnattended}" == true ]]; then
		echo "::: --unattended passed to install script, no whiptail dialogs will be displayed"
		if [ -z "$unattendedConfig" ]; then
			echo "::: No configuration file passed"
			exit 1
		else
			if [ -r "$unattendedConfig" ]; then
				# shellcheck disable=SC1090
				source "$unattendedConfig"
			else
				echo "::: Can't open $unattendedConfig"
				exit 1
			fi
		fi
	fi


# INITIALIZATION
	# Check for supported distribution
	distroCheck

	# Checks for hostname Length
	setHostname

	# Start the installer
	# Verify there is enough disk space for the install
	if [[ "${skipSpaceCheck}" == true ]]; then
		echo "::: --skip-space-check passed to script, skipping free disk space verification!"
	else
		verifyFreeDiskSpace
	fi

	updatePackageCache

	# Notify user of package availability
	notifyPackageUpdatesAvailable

	# Install packages used by this installation script
	preconfigurePackages
	installDependentPackages BASE_DEPS[@]

	# Display welcome dialogs
	welcomeDialogs

	# Find interfaces and let the user choose one
	chooseInterface

	if [ "$PLAT" != "Raspbian" ]; then
		avoidStaticIPv4Ubuntu
	else
		getStaticIPv4Settings
		if [ -z "$dhcpReserv" ] || [ "$dhcpReserv" -ne 1 ]; then
			setStaticIPv4
		fi
	fi

	# Choose the user
	chooseUser

	# Clone/Update the repos
	cloneOrUpdateRepos

	# Install
	if installTripwirePi; then
		echo "::: Install Complete..."
	else
		exit 1
	fi

	# Start services
	restartServices

	# Ask if unattended-upgrades will be enabled
	askUnattendedUpgrades

	if [ "$UNATTUPG" -eq 1 ]; then
		confUnattendedUpgrades
	fi

	# Save installation setting to the final location
	echo "INSTALLED_PACKAGES=(${INSTALLED_PACKAGES[*]})" >> ${tempsetupVarsFile}
        echo "::: Setupfiles copied to ${setupConfigDir}/${VPN}/${setupVarsFile}"
        $SUDO mkdir -p "${setupConfigDir}/${VPN}/"
	$SUDO cp ${tempsetupVarsFile} "${setupConfigDir}/${VPN}/${setupVarsFile}"

	installScripts

	# Ensure that cached writes reach persistent storage
	echo "::: Flushing writes to disk..."
	sync
	echo "::: done."

	displayFinalMessage
	echo ":::"
}


# CODE CHUNKS WELCOME AND NETWORKING

welcomeDialogs(){
	if [ "${runUnattended}" = 'true' ]; then
		echo "::: PiVPN Automated Installer"
		echo "::: This installer will transform your ${PLAT} host into an OpenVPN or WireGuard server!"
		echo "::: Initiating network interface"
		return
	fi

	# Display the welcome dialog
	whiptail --msgbox --backtitle "Welcome" --title "PiVPN Automated Installer" "This installer will transform your Raspberry Pi into an OpenVPN or WireGuard server!" ${r} ${c}

	# Explain the need for a static address
	whiptail --msgbox --backtitle "Initiating network interface" --title "Static IP Needed" "The PiVPN is a SERVER so it needs a STATIC IP ADDRESS to function properly.
In the next section, you can choose to use your current network settings (DHCP) or to manually edit them." ${r} ${c}
}

chooseInterface(){
# Turn the available interfaces into an array so it can be used with a whiptail dialog
local interfacesArray=()
# Number of available interfaces
local interfaceCount
# Whiptail variable storage
local chooseInterfaceCmd
# Temporary Whiptail options storage
local chooseInterfaceOptions
# Loop sentinel variable
local firstloop=1

if [[ "${showUnsupportedNICs}" == true ]]; then
	# Show every network interface, could be useful for those who install PiVPN inside virtual machines
	# or on Raspberry Pis with USB adapters (the loopback interfaces is still skipped)
	availableInterfaces=$(ip -o link | awk '{print $2}' | cut -d':' -f1 | cut -d'@' -f1 | grep -v -w 'lo')
else
	# Find network interfaces whose state is UP, so as to skip virtual interfaces and the loopback interface
	availableInterfaces=$(ip -o link | awk '/state UP/ {print $2}' | cut -d':' -f1 | cut -d'@' -f1)
fi

if [ -z "$availableInterfaces" ]; then
    echo "::: Could not find any active network interface, exiting"
    exit 1
else
    while read -r line; do
        mode="OFF"
        if [[ ${firstloop} -eq 1 ]]; then
            firstloop=0
            mode="ON"
        fi
        interfacesArray+=("${line}" "available" "${mode}")
        ((interfaceCount++))
    done <<< "${availableInterfaces}"
fi

if [ "${runUnattended}" = 'true' ]; then
    if [ -z "$IPv4dev" ]; then
        if [ $interfaceCount -eq 1 ]; then
            IPv4dev="${availableInterfaces}"
            echo "::: No interface specified, but only ${IPv4dev} is available, using it"
        else
            echo "::: No interface specified and failed to determine one"
            exit 1
        fi
    else
        if ip -o link | grep -qw "${IPv4dev}"; then
            echo "::: Using interface: ${IPv4dev}"
        else
          	echo "::: Interface ${IPv4dev} does not exist"
            exit 1
        fi
    fi
    echo "IPv4dev=${IPv4dev}" >> ${tempsetupVarsFile}
    return
else
    if [ "$interfaceCount" -eq 1 ]; then
        IPv4dev="${availableInterfaces}"
        echo "IPv4dev=${IPv4dev}" >> ${tempsetupVarsFile}
        return
    fi
fi

chooseInterfaceCmd=(whiptail --separate-output --radiolist "Choose An interface (press space to select):" "${r}" "${c}" "${interfaceCount}")
if chooseInterfaceOptions=$("${chooseInterfaceCmd[@]}" "${interfacesArray[@]}" 2>&1 >/dev/tty) ; then
    for desiredInterface in ${chooseInterfaceOptions}; do
        IPv4dev=${desiredInterface}
        echo "::: Using interface: $IPv4dev"
        echo "IPv4dev=${IPv4dev}" >> ${tempsetupVarsFile}
    done
else
    echo "::: Cancel selected, exiting...."
    exit 1
fi
}

avoidStaticIPv4Ubuntu() {
	if [ "${runUnattended}" = 'true' ]; then
		echo "::: Since we think you are not using Raspbian, we will not configure a static IP for you."
		return
	fi

	# If we are in Ubuntu then they need to have previously set their network, so just use what you have.
	whiptail --msgbox --backtitle "IP Information" --title "IP Information" "Since we think you are not using Raspbian, we will not configure a static IP for you.
If you are in Amazon then you can not configure a static IP anyway. Just ensure before this installer started you had set an elastic IP on your instance." ${r} ${c}
}

validIP(){
	local ip=$1
	local stat=1

	if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
		OIFS=$IFS
		IFS='.'
		read -r -a ip <<< "$ip"
		IFS=$OIFS
		[[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
		&& ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
		stat=$?
	fi
	return $stat
}

validIPAndNetmask(){
	local ip=$1
	local stat=1
	ip="${ip/\//.}"

	if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,2}$ ]]; then
		OIFS=$IFS
		IFS='.'
		read -r -a ip <<< "$ip"
		IFS=$OIFS
		[[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
		&& ${ip[2]} -le 255 && ${ip[3]} -le 255 \
		&& ${ip[4]} -le 32 ]]
		stat=$?
	fi
	return $stat
}

getStaticIPv4Settings() {
	# Find the gateway IP used to route to outside world
	CurrentIPv4gw="$(ip -o route get 192.0.2.1 | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | awk 'NR==2')"

	# Find the IP address (and netmask) of the desidered interface
	CurrentIPv4addr="$(ip -o -f inet address show dev "${IPv4dev}" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/[0-9]{1,2}')"

	# Grab their current DNS servers
	IPv4dns=$(grep -v "^#" /etc/resolv.conf | grep -w nameserver | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | xargs)

	if [ "${runUnattended}" = 'true' ]; then

		if [ -z "$dhcpReserv" ] || [ "$dhcpReserv" -ne 1 ]; then
			local MISSING_STATIC_IPV4_SETTINGS=0

			if [ -z "$IPv4addr" ]; then
				echo "::: Missing static IP address"
				((MISSING_STATIC_IPV4_SETTINGS++))
			fi

			if [ -z "$IPv4gw" ]; then
				echo "::: Missing static IP gateway"
				((MISSING_STATIC_IPV4_SETTINGS++))
			fi

			if [ "$MISSING_STATIC_IPV4_SETTINGS" -eq 0 ]; then

				# If both settings are not empty, check if they are valid and proceed
				if validIPAndNetmask "${IPv4addr}"; then
					echo "::: Your static IPv4 address:    ${IPv4addr}"
				else
					echo "::: ${IPv4addr} is not a valid IP address"
					exit 1
				fi

				if validIP "${IPv4gw}"; then
					echo "::: Your static IPv4 gateway:    ${IPv4gw}"
				else
					echo "::: ${IPv4gw} is not a valid IP address"
					exit 1
				fi

			elif [ "$MISSING_STATIC_IPV4_SETTINGS" -eq 1 ]; then

				# If either of the settings is missing, consider the input inconsistent
				echo "::: Incomplete static IP settings"
				exit 1

			elif [ "$MISSING_STATIC_IPV4_SETTINGS" -eq 2 ]; then

				# If both of the settings are missing, assume the user wants to use current settings
				IPv4addr="${CurrentIPv4addr}"
				IPv4gw="${CurrentIPv4gw}"
				echo "::: No static IP settings, using current settings"
				echo "::: Your static IPv4 address:    ${IPv4addr}"
				echo "::: Your static IPv4 gateway:    ${IPv4gw}"

			fi
		else
			echo "::: Skipping setting static IP address"
		fi

		echo "dhcpReserv=${dhcpReserv}" >> ${tempsetupVarsFile}
		echo "IPv4addr=${IPv4addr}" >> ${tempsetupVarsFile}
		echo "IPv4gw=${IPv4gw}" >> ${tempsetupVarsFile}
		return
	fi

	local ipSettingsCorrect
	local IPv4AddrValid
	local IPv4gwValid
	# Some users reserve IP addresses on another DHCP Server or on their routers,
	# Lets ask them if they want to make any changes to their interfaces.

	if (whiptail --backtitle "Calibrating network interface" --title "DHCP Reservation" --yesno --defaultno \
	"Are you Using DHCP Reservation on your Router/DHCP Server?
These are your current Network Settings:
			IP address:    ${CurrentIPv4addr}
			Gateway:       ${CurrentIPv4gw}
Yes: Keep using DHCP reservation
No: Setup static IP address
Don't know what DHCP Reservation is? Answer No." ${r} ${c}); then
		dhcpReserv=1
        # shellcheck disable=SC2129
		echo "dhcpReserv=${dhcpReserv}" >> ${tempsetupVarsFile}
		# We don't really need to save them as we won't set a static IP but they might be useful for debugging
		echo "IPv4addr=${CurrentIPv4addr}" >> ${tempsetupVarsFile}
		echo "IPv4gw=${CurrentIPv4gw}" >> ${tempsetupVarsFile}
	else
		# Ask if the user wants to use DHCP settings as their static IP
		if (whiptail --backtitle "Calibrating network interface" --title "Static IP Address" --yesno "Do you want to use your current network settings as a static address?
				IP address:    ${CurrentIPv4addr}
				Gateway:       ${CurrentIPv4gw}" ${r} ${c}); then
			IPv4addr=${CurrentIPv4addr}
			IPv4gw=${CurrentIPv4gw}
			echo "IPv4addr=${IPv4addr}" >> ${tempsetupVarsFile}
			echo "IPv4gw=${IPv4gw}" >> ${tempsetupVarsFile}

			# If they choose yes, let the user know that the IP address will not be available via DHCP and may cause a conflict.
			whiptail --msgbox --backtitle "IP information" --title "FYI: IP Conflict" "It is possible your router could still try to assign this IP to a device, which would cause a conflict.  But in most cases the router is smart enough to not do that.
If you are worried, either manually set the address, or modify the DHCP reservation pool so it does not include the IP you want.
It is also possible to use a DHCP reservation, but if you are going to do that, you might as well set a static address." ${r} ${c}
			# Nothing else to do since the variables are already set above
		else
			# Otherwise, we need to ask the user to input their desired settings.
			# Start by getting the IPv4 address (pre-filling it with info gathered from DHCP)
			# Start a loop to let the user enter their information with the chance to go back and edit it if necessary
			until [[ ${ipSettingsCorrect} = True ]]; do

				until [[ ${IPv4AddrValid} = True ]]; do
					# Ask for the IPv4 address
					if IPv4addr=$(whiptail --backtitle "Calibrating network interface" --title "IPv4 address" --inputbox "Enter your desired IPv4 address" ${r} ${c} "${CurrentIPv4addr}" 3>&1 1>&2 2>&3) ; then
						if validIPAndNetmask "${IPv4addr}"; then
							echo "::: Your static IPv4 address:    ${IPv4addr}"
							IPv4AddrValid=True
						else
							whiptail --msgbox --backtitle "Calibrating network interface" --title "IPv4 address" "You've entered an invalid IP address: ${IPv4addr}\\n\\nPlease enter an IP address in the CIDR notation, example: 192.168.23.211/24\\n\\nIf you are not sure, please just keep the default." ${r} ${c}
							echo "::: Invalid IPv4 address:    ${IPv4addr}"
							IPv4AddrValid=False
						fi
					else
						# Cancelling IPv4 settings window
						echo "::: Cancel selected. Exiting..."
						exit 1
					fi
				done

				until [[ ${IPv4gwValid} = True ]]; do
					# Ask for the gateway
					if IPv4gw=$(whiptail --backtitle "Calibrating network interface" --title "IPv4 gateway (router)" --inputbox "Enter your desired IPv4 default gateway" ${r} ${c} "${CurrentIPv4gw}" 3>&1 1>&2 2>&3) ; then
						if validIP "${IPv4gw}"; then
							echo "::: Your static IPv4 gateway:    ${IPv4gw}"
							IPv4gwValid=True
						else
							whiptail --msgbox --backtitle "Calibrating network interface" --title "IPv4 gateway (router)" "You've entered an invalid gateway IP: ${IPv4gw}\\n\\nPlease enter the IP address of your gateway (router), example: 192.168.23.1\\n\\nIf you are not sure, please just keep the default." ${r} ${c}
							echo "::: Invalid IPv4 gateway:    ${IPv4gw}"
							IPv4gwValid=False
						fi
					else
						# Cancelling gateway settings window
						echo "::: Cancel selected. Exiting..."
						exit 1
					fi
				done

				# Give the user a chance to review their settings before moving on
				if (whiptail --backtitle "Calibrating network interface" --title "Static IP Address" --yesno "Are these settings correct?
						IP address:    ${IPv4addr}
						Gateway:       ${IPv4gw}" ${r} ${c}); then
					# If the settings are correct, then we need to set the pivpnIP
					echo "IPv4addr=${IPv4addr}" >> ${tempsetupVarsFile}
					echo "IPv4gw=${IPv4gw}" >> ${tempsetupVarsFile}
					# After that's done, the loop ends and we move on
					ipSettingsCorrect=True
				else
					# If the settings are wrong, the loop continues
					ipSettingsCorrect=False
					IPv4AddrValid=False
					IPv4gwValid=False
				fi
			done
			# End the if statement for DHCP vs. static
		fi
		# End of If Statement for DCHCP Reservation
	fi
}

setDHCPCD(){
	# Append these lines to dhcpcd.conf to enable a static IP
	echo "interface ${IPv4dev}
	static ip_address=${IPv4addr}
	static routers=${IPv4gw}
	static domain_name_servers=${IPv4dns}" | $SUDO tee -a ${dhcpcdFile} >/dev/null
}

setStaticIPv4(){
	# Tries to set the IPv4 address
	if [[ -f /etc/dhcpcd.conf ]]; then
		if grep -q "${IPv4addr}" ${dhcpcdFile}; then
			echo "::: Static IP already configured."
		else
			setDHCPCD
			$SUDO ip addr replace dev "${IPv4dev}" "${IPv4addr}"
			echo ":::"
			echo "::: Setting IP to ${IPv4addr}.  You may need to restart after the install is complete."
			echo ":::"
		fi
	else
		echo "::: Critical: Unable to locate configuration file to set static IPv4 address!"
		exit 1
	fi
}
# Compatibility, functions to check for supported OS
# distroCheck, maybeOSSupport, noOSSupport
distroCheck(){
	# if lsb_release command is on their system
	if command -v lsb_release > /dev/null; then

		PLAT=$(lsb_release -si)
		OSCN=$(lsb_release -sc)

	else # else get info from os-release

		# shellcheck disable=SC1091
		source /etc/os-release
		PLAT=$(awk '{print $1}' <<< "$NAME")
		VER="$VERSION_ID"
		declare -A VER_MAP=(["9"]="stretch" ["10"]="buster" ["16.04"]="xenial" ["18.04"]="bionic" ["20.04"]="focal")
		OSCN=${VER_MAP["${VER}"]}
	fi

	case ${PLAT} in
		Debian|Raspbian|Ubuntu)
			case ${OSCN} in
				stretch|buster|xenial|bionic|focal)
				:
				;;
				*)
				maybeOSSupport
				;;
			esac
		;;
		*)
		noOSSupport
		;;
	esac

	echo "PLAT=${PLAT}" > ${tempsetupVarsFile}
	echo "OSCN=${OSCN}" >> ${tempsetupVarsFile}
}

noOSSupport(){
	if [ "${runUnattended}" = 'true' ]; then
		echo "::: Invalid OS detected"
		echo "::: We have not been able to detect a supported OS."
		echo "::: Currently this installer supports Raspbian, Debian and Ubuntu."
		exit 1
	fi

	whiptail --msgbox --backtitle "INVALID OS DETECTED" --title "Invalid OS" "We have not been able to detect a supported OS.
Currently this installer supports Raspbian, Debian and Ubuntu.
For more details, check our documentation at https://github.com/pivpn/pivpn/wiki " ${r} ${c}
	exit 1
}

maybeOSSupport(){
	if [ "${runUnattended}" = 'true' ]; then
		echo "::: OS Not Supported"
		echo "::: You are on an OS that we have not tested but MAY work, continuing anyway..."
		return
	fi

	if (whiptail --backtitle "Untested OS" --title "Untested OS" --yesno "You are on an OS that we have not tested but MAY work.
Currently this installer supports Raspbian, Debian and Ubuntu.
For more details about supported OS please check our documentation at https://github.com/pivpn/pivpn/wiki
Would you like to continue anyway?" ${r} ${c}) then
		echo "::: Did not detect perfectly supported OS but,"
		echo "::: Continuing installation at user's own risk..."
	else
		echo "::: Exiting due to untested OS"
		exit 1
	fi
}


setHostname(){
###Dialogue for setting hostname
	host_name=$(hostname -s)
	if [ "${runUnattended}" = 'true' ]; then
		echo "::: Configure a Customized hostname"
		echo "::: Use 'hostnamectl set-hostname YOURHOSTNAME' to set a new hostname"

		exit 1
	fi
	until [[ ${#host_name} != "raspberry"]]; do
		host_name=$(whiptail --inputbox "Configure a new hostname for your device.\\nMust be less than 28 characters\\nProvide a name that matches the service hosted while adhereing to the naming scheme used by adjacent devices.\\nRead the guidelines for naming your device at https://github.com/Notorious-AFK/TripwirePi/blob/main/README.md" \
	   --title "Set Hostname" ${r} ${c} 3>&1 1>&2 2>&3)
		$SUDO hostnamectl set-hostname "${host_name}"
		if [[ ${#host_name} -le 28 && $host_name  =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,28}$  ]] && $host_name != "raspberry"; then
			echo "::: Hostname valid and length OK, proceeding..."
		fi
	done
else
	echo "::: Hostname length OK"
fi
}

spinner(){
	local pid=$1
	local delay=0.50
	local spinstr='/-\|'
	while ps a | awk '{print $1}' | grep -q "$pid"; do
		local temp=${spinstr#?}
		printf " [%c]  " "${spinstr}"
		local spinstr=${temp}${spinstr%"$temp"}
		sleep ${delay}
		printf "\\b\\b\\b\\b\\b\\b"
	done
	printf "    \\b\\b\\b\\b"
}

verifyFreeDiskSpace(){
	# If user installs unattended-upgrades we'd need about 60MB so will check for 75MB free
	echo "::: Verifying free disk space..."
	local required_free_kilobytes=76800
	local existing_free_kilobytes
	existing_free_kilobytes=$(df -Pk | grep -m1 '\/$' | awk '{print $4}')

	# - Unknown free disk space , not a integer
	if ! [[ "${existing_free_kilobytes}" =~ ^([0-9])+$ ]]; then
		echo "::: Unknown free disk space!"
		echo "::: We were unable to determine available free disk space on this system."
		if [ "${runUnattended}" = 'true' ]; then
			exit 1
		fi
		echo "::: You may continue with the installation, however, it is not recommended."
		read -r -p "::: If you are sure you want to continue, type YES and press enter :: " response
		case $response in
			[Y][E][S])
				;;
			*)
				echo "::: Confirmation not received, exiting..."
				exit 1
				;;
		esac
	# - Insufficient free disk space
	elif [[ ${existing_free_kilobytes} -lt ${required_free_kilobytes} ]]; then
		echo "::: Insufficient Disk Space!"
		echo "::: Your system appears to be low on disk space. PiVPN recommends a minimum of $required_free_kilobytes KiloBytes."
		echo "::: You only have ${existing_free_kilobytes} KiloBytes free."
		echo "::: If this is a new install on a Raspberry Pi you may need to expand your disk."
		echo "::: Try running 'sudo raspi-config', and choose the 'expand file system option'"
		echo "::: After rebooting, run this installation again. (curl -L https://install.pivpn.io | bash)"

		echo "Insufficient free space, exiting..."
		exit 1
	fi
}
