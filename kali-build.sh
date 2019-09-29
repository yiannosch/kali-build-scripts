#!/bin/bash

##Todo:
# 1) install burpsuite pro (pending)
# 2) activate nessus ?
# 3) install rpclient, rusers, nbtscan-unixwiz
# 4) change UI
# 5) Change background image
# 6) Generate ssh keys sshkeygen
# 7) ZSH is asking if you want to change your default shell during installation. get rid of this???
# 8) Install blodhound + neo4j
# 9) Add firefox bookmarks (pending) useful bookmarks + nessus, bloodhound
# 10) Crete a tools folder and install more tools web, infra, web services network etc.
# 11) Install EyeWitness and GoWitness
#  tools: hoppy, drupwn, drupscan, testssl, eicar,fuzzdb, IIS_shortname scanner, qualys ssllabs, redsnarf, ysoserial, barmie, .net serial
# unicorn,

####Get latest version####
#wget -q https://github.com/yiannosch/kali-build-scripts/blob/master/kali-build.sh && bash kali-build.sh

####--Defaults--####

####--Timezone and keyboard settings--####
keyboardApple=false       		# Using a Apple/Macintosh keyboard (non VM)?      [ --osx ]
keyboardlayout="gb"           # Set keyboard layout                             [ --keyboard gb ]
timezone="Europe/London"      # Set timezone location                           [ --timezone Europe/London ]
hostname="kali"
inputSources="[('xkb', 'gb')]" #Set keyboard to gb
# Add your preferred keyboard layouts such as [('xkb', 'gb'), ('xkb', 'us'), ('xkb', 'gr')]


####-- Licenses and Keys --####
nessusKey=""           # Nessus Pro license key
sshPass=""             # Password for ssh private key

####-- (Cosmetic) Colour output --####
RED="\033[01;31m"      # Issues/Errors
GREEN="\033[01;32m"    # Success
YELLOW="\033[01;33m"   # Warnings/Information
BLUE="\033[01;34m"     # Heading
BOLD="\033[01;01m"     # Highlight
RESET="\033[00m"       # Normal

####-- Monitor progress --####
STAGE=0                                                           # Where are we up to
TOTAL="$( grep '(${STAGE}/${TOTAL})' $0 | wc -l;(( TOTAL-- )))"   # How many things have we got todo

####-- Other settings --####
CHECKDNS=google.com

######### Start ##########

#Check if runnign as root. Return error otherwise
# if [[ ${EUID} -ne 0 ]]; then #Don't need it for now
# 	echo -e ' '${RED}'[!]'${RESET}" This script must be ${RED}run as root${RESET}. Quitting..." 1>&2
#   exit 1
# else
#   echo -e " ${BLUE}[*]${RESET} ${BOLD}Kali Linux 2019.2 build script${RESET}"
# fi


#### Parsing command line arguments ####

OPTS=`getopt -o bh --long burp,help -n 'parse-options' -- "$@"`

if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi
echo "$OPTS"
eval set -- "$OPTS"

HELP=false
BURP=false

while true; do
  case "$1" in
    -b | --burp )    BURP=true; shift ;;
    -h | --help )    HELP=true; shift ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

#Check internet connection
(( STAGE++ ))
echo -e "\n ${BLUE}[*]${RESET} (${STAGE}/${TOTAL}) Checking ${BLUE}Internet access${RESET}"
if ! nc -zw1 $CHECKDNS 443 >/dev/null 2>&1; then
  echo -e " ${RED}[!]${RESET}${BOLD}Connection failed!${RESET} Please check your internet connection and run the script again!" 1>&2
  exit 1
else
  echo -e " ${GREEN}[+]${RESET} ${GREEN}Detected Internet access${RESET}" 1>&2
fi

#### Update OS ####
(( STAGE++ ))
echo -e "\n ${GREEN}[+]${RESET} (${STAGE}/${TOTAL})${BOLD} Updating OS from repositories${RESET} (this may take a while depending on your Internet connection & Kali version/age)"
wait 5s
apt -q update && APT_LISTCHANGES_FRONTEND=none apt -o Dpkg::Options::="--force-confnew" -y -q full-upgrade --fix-missing
apt -y -q autoclean && apt -y -q autoremove


####Detect VM environment####
#Only VMware supported for now
(( STAGE++ ))
echo -e " ${BLUE}[*]${RESET} (${STAGE}/${TOTAL})${BOLD} Identifying running environment...${RESET}"
if (dmidecode | grep -i vmware); then
	echo -e " ${YELLOW}[i]${RESET} VMware detected."
	#Remove vmware tools and install open-vm-tools if not installed.
	_VMTOOLS=/usr/bin/vmware-uninstall-tools.pl
	if [ -f "$_VMTOOLS" ]; then
		echo -e " ${YELLOW}[i]${RESET} VMwareTools found.\n Proceeding to uninstall!"
		perl /usr/bin/vmware-uninstall-tools.pl
	else
		echo -e " $YELLOW[i]$RESET VMwareTools not found."
	fi
	_VMTOOLS=$(dpkg -l | grep -i 'open-vm-tools')
	echo "${YELLOW}[i]${RESET} ${BOLD}Checking for open-vm-tools"
	if [  "$_VMTOOLS" = "" ]; then
		echo -e " ${YELLOW}[i]${RESET} ${BOLD}open-vm-tools not found on the host.\n Proceeding to install${RESET}"
		apt -y -q install open-vm-tools # install open-vm-tools
	else
		echo -e " ${GREEN}[+]${RESET} ${BOLD}open-vm-tools already installed! Skipping installation."
	fi

elif (dmidecode | grep -i virtualbox); then
	echo " ${YELLOW}[i]${RESET} Virtualbox detected."
	if [ -e "/etc/init.d/virtualbox-guest-utils" ]; then
		echo " ${RED}[!]${RESET} Virtualbox Guest Additions are already installed. Skipping..."
	else
		echo -e " ${GREEN}[+]${RESET} Installing Virtualbox Guest Additions"
		apt -y -q virtualbox-guest-utils
	fi
else
  echo -e " ${RED}[!]${RESET} VM platform cound not be found. Skipping..."
fi

#Check kernel
#Find installed kernels packages
(( STAGE++ ))
echo -e "\n ${BLUE}[*]${RESET} (${STAGE}/${TOTAL}) Checking ${BLUE}kernel version ${RESET}"
_KRL=$(dpkg -l | grep linux-image- | grep -vc meta)
if [[ "$_KRL" -gt 1 ]]; then
  echo -e " ${YELLOW}[i]${RESET}Detected multiple kernels installed"
  #Remove kernel packages marked as rc
  dpkg -l | grep linux-image | grep "^rc" | cut -d " " -f 3 | xargs dpkg --purge
  KRL=$(dpkg -l | grep linux-image | grep -v meta | sort -t '.' -k 2 -g | tail -n 1 | grep "$(uname -r)")
  [[ -z "$_KRL" ]] && echo -e "${RED}[!]${RESET} You are not using the latest kernel" 1>&2 && echo -e " ${YELLOW}[i]${RESET} You have it downloaded & installed, just not using it. You need to **reboot**"
fi

#install linux headers
(( STAGE++ ))
echo -e "\n ${BLUE}[*]${RESET} (${STAGE}/${TOTAL}) Checking for ${BLUE}kernel headers${RESET}"
apt -y -q install "linux-headers-$(uname -r)"


#### Updating hostname to preset value. If default is selected then skip ####
#echo -e "\n $GREEN[+]$RESET Updating hostname"
#Default hostname is kali
(( STAGE++ ))
echo -e "\n ${BLUE}[*]${RESET} (${STAGE}/${TOTAL}) Checking ${BLUE}hostname${RESET}"
if [ "$hostname" = "kali" ]; then
	echo -e " ${YELLOW}[*]${RESET} ${BOLD}Hostname is set to default.\n No changes applied${RESET}"
else
	hostname $hostname
	#Make sure it remains after reboot
	file=/etc/hostname; [ -e "$file" ]
	echo "$(hostname)" > "$file"

	#Changes must applied in hosts file too
	file=/etc/hosts; [ -e "$file" ]
	sed -i 's/127.0.1.1.*/127.0.1.1  '$hostname'/' "$file"
	echo -e "127.0.0.1  localhost localhost\n127.0.0.1 $hostname" > "$file"

	#Verify changes
	echo -e " ${GREEN}[+]${RESET} ${BOLD}Hostname changed. ${RESET}"
	hostname
fi

#### Configure keyboard layout ####

#--- Configure keyboard layout
(( STAGE++ ))
echo -e "\n ${BLUE}[*]${RESET} (${STAGE}/${TOTAL}) Configuring ${BLUE}keyboard layout${RESET}"
if [ ! -z "$keyboardlayout" ]; then
	file=/etc/default/keyboard; #[ -e "$file" ] && cp -n $file{,.bkup}
	sed -i 's/XKBLAYOUT=".*"/XKBLAYOUT="'$keyboardlayout'"/' "$file"
	#[ "$keyboardApple" != "false" ] && sed -i 's/XKBVARIANT=".*"/XKBVARIANT="mac"/' "$file"   # Enable if you are using Apple based products.

	dpkg-reconfigure -f noninteractive keyboard-configuration   #dpkg-reconfigure console-setup   #dpkg-reconfigure keyboard-configuration -u    # Need to restart xserver for effect
fi

#Change locale
sed -i '
s/^# en_GB/en_GB/
s/^# en_US/en_US/
' /etc/locale.gen   #en_GB en_US

locale-gen

echo -e 'LC_ALL=en_GB.UTF-8\nLANG=en_GB.UTF-8\nLANGUAGE=en_GB:en' > /etc/default/locale
dpkg-reconfigure -f noninteractive tzdata #Reboot is required to apply changes

#Change keyboard to GB. Remove the rest :)
gsettings set org.gnome.desktop.input-sources sources "$inputSources"

#--- Changing time zone
(( STAGE++ ))
echo -e "\n ${BLUE}[*]${RESET} (${STAGE}/${TOTAL}) Configuring ${BLUE}timezone${RESET}"
[ -z "$timezone" ] && timezone=Etc/UTC     #Etc/GMT vs Etc/UTC vs UTC
echo "$timezone" > /etc/timezone           #Default is Europe/London
ln -sf "/usr/share/zoneinfo/$(cat /etc/timezone)" /etc/localtime

#### Add gnome keyboard shortcuts ####
#Add CTRL+ALT+T for terminal, same as Ubuntu
#Bindings are hardcoded for now.
(( STAGE++ ))
echo -e "\n ${BLUE}[*]${RESET} (${STAGE}/${TOTAL}) Applying changes to GNOME settings"
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/']"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ name "Terminal"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ command "gnome-terminal"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ binding "<CTRL><ALT>T"

####Set background wallpaper####
#Setting wallpaper of my choice for now.
#More options will be added in a future release
gsettings set org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/gnome/endless-shapes.jpg'

#Configure gnome favourites bar
gsettings set org.gnome.shell favorite-apps "['org.gnome.Terminal.desktop', 'firefox-esr.desktop', 'org.gnome.Nautilus.desktop', 'kali-msfconsole.desktop', 'gnome-control-center.desktop', 'kali-burpsuite.desktop', 'sublime_text.desktop', 'atom.desktop']"

#Set theme (Kali Dark)
gsettings set org.gnome.desktop.interface gtk-theme "Kali-X-Dark"
#Set icon theme (Zen kali)
gsettings set org.gnome.desktop.interface icon-theme "Zen-Kali"
#Set power saving time (15 minutes)
gsettings set org.gnome.desktop.session idle-delay "uint32 900"
#Enable date on clock panel
dconf write /org/gnome/desktop/interface/clock-show-date "true"

#Change AltTab behaviour
gsettings set org.gnome.desktop.wm.keybindings switch-applications "['<Super>Tab']"
gsettings set org.gnome.desktop.wm.keybindings switch-windows "['<Alt>Tab']"

#Enable nano line numbering
sed -i 's/^# set linenumbers/set linenumbers/' /etc/nanorc

####Install zsh from github####
#Download oh-my-zsh
(( STAGE++ ))
echo -e "\n ${BLUE}[*]${RESET} (${STAGE}/${TOTAL}) Installing ${BLUE}zsh shell ${RESET}"

wget -q https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh
chmod +x install.sh
./install.sh --unattended
ZSH=${ZSH:-~/.oh-my-zsh}
export SHELL="$ZSH"
#Fix .zsh path, add /root/.loca/bin to PATH
sed -i '4iexport PATH=$PATH:/root/.local/bin' $HOME/.zshrc

#Change zsh theme
sed -i -e 's/ZSH_THEME=.*/ZSH_THEME="robbyrussell"/g' $HOME/.zshrc

#add alias in .zshrc
echo -e 'alias lh="ls -lAh"\nalias la="ls -la"\nalias ll="ls -l"' >> $HOME/.zshrc
rm install.sh


####Install Sublime 3####
(( STAGE++ ))
echo -e "\n ${BLUE}[*]${RESET} (${STAGE}/${TOTAL}) Installing ${BLUE}Sublime 3 editor ${RESET}"
wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | apt-key add -
wget -qO - https://packagecloud.io/AtomEditor/atom/gpgkey | apt-key add -  #Added Atom config here to avoid updating sources multiple times
apt install -y -qq apt-transport-https
echo "deb https://download.sublimetext.com/ apt/stable/" | tee /etc/apt/sources.list.d/sublime-text.list
echo "deb [arch=amd64] https://packagecloud.io/AtomEditor/atom/any/ any main" | tee /etc/apt/sources.list.d/atom.list
apt -qq update && apt install -y -q sublime-text

#Sublime 3 packages to install#
(( STAGE++ ))
echo -e "\n ${BLUE}[*]${RESET} (${STAGE}/${TOTAL}) Installing ${BLUE}Sublime packages ${RESET}"
#Indent XML
git clone https://github.com/alek-sys/sublimetext_indentxml.git "$HOME/.config/sublime-text-3/Packages/sublimetext_indentxml"
#HTML/CSS/JS pretify
git clone https://github.com/victorporof/Sublime-HTMLPrettify.git "$HOME/.config/sublime-text-3/Packages/Sublime-HTMLPrettify"


####Install Atom####
(( STAGE++ ))
echo -e "\n ${BLUE}[*]${RESET} (${STAGE}/${TOTAL}) Installing ${BLUE}Atom editor ${RESET}"
apt install -y -q atom

#### Install crackmapexec with pipenv ####
(( STAGE++ ))
echo -e "\n ${BLUE}[*]${RESET} (${STAGE}/${TOTAL}) Installing ${BLUE}crackmapexec ${RESET}"
apt install -y -q libssl-dev libffi-dev python-dev build-essential python-pip
sleep 5
pip install --user pipenv
git clone --recursive https://github.com/byt3bl33d3r/CrackMapExec "$HOME/Downloads/"

file="$HOME/.local/bin/pipenv"
if [ -s "$file" ]; then
	cd "$HOME/Downloads/CrackMapExec" && "$file" install
	"$file" shell
	python setup.py install
else
	echo "${RED}[!]${RESET} Something went wrong. Installation of ${RED}${BOLD}CrackMapExec ${RESET}has failed!"
fi

#### Install Winpayloads ####
(( STAGE++ ))
echo -e "\n ${BLUE}[*]${RESET} (${STAGE}/${TOTAL}) Installing ${BLUE}Winpayloads ${RESET}"
#check if docker is running
if [[ $(systemctl status docker) != *"active (running)"* ]]; then
	echo "${YELLOW}[i]${RESET} starting docker service"
	systemctl start docker
	sleep 5
fi
echo -e "${YELLOW}[i]${RESET} Pulling ${YELLOW}Docker image${RESET}..."
docker pull charliedean07/winpayloads:latest

#### Init msfdb ####
(( STAGE++ ))
echo -e "\n ${BLUE}[*]${RESET} (${STAGE}/${TOTAL}) msfconsole setup ${RESET}"
msfdb init
if [ "$SHELL" = "/bin/zsh" ]; then echo 'alias msf="msfconsole"' >> $HOME/.zshrc; fi

#Adding postgreSQL service to startup
echo -e " ${YELLOW}[i]${RESET} Enabled ${YELLOW}postgresql ${RESET}service "
update-rc.d postgresql enable


#### Install SoapUI ####
(( STAGE++ ))
echo -e "\n ${BLUE}[*]${RESET} (${STAGE}/${TOTAL}) Installing ${BLUE}SoapUI ${RESET}"
#Download the sh installer
wget https://s3.amazonaws.com/downloads.eviware/soapuios/5.5.0/SoapUI-x64-5.5.0.sh -P ~/Downloads/
file="/root/Downloads/SoapUI-x64-5.5.0.sh"
# Search for installer in tmp, Downloads and current directory
if [ -s $file ]; then
  echo -e " ${YELLOW}[i]${RESET} ${BOLD}Modifying SoapUI installer.\Proceeding with installation${RESET}"
  #Modifying the installer to shut up
  sed -i -e 's/com.install4j.runtime.installer.Installer/com.install4j.runtime.installer.Installer -q/g' $file
  sh $file
  rm "$file"
fi

#Create directory structure to dowonload tools
(( STAGE++ ))
echo -e "\n ${BLUE}[*]${RESET} (${STAGE}/${TOTAL}) Creating tools directory"
mkdir -p -v -Z /root/Tools/Webapp/ /root/Tools/Infrastructure/Linux /root/Tools/Infrastructure/Windows

#Download tools
pip install droopescan

git clone https://github.com/immunIT/drupwn.git "$/root/Tools/Webapp/drupwn"
python3 setup.py install

#ScoutSuite
virtualenv -p python3 scoutsuite
source scoutsuite/bin/activate
pip install scoutsuite


# Download dirble latest release from github
(( STAGE++ ))
echo -e "\n ${BLUE}[*]${RESET} (${STAGE}/${TOTAL}) Installing${BLUE}dirble${RESET}"
zipfile=`curl --silent "https://api.github.com/repos/nccgroup/dirble/releases/latest" | grep '"browser_download_url"' | grep "64-linux" | sed -E 's/.*"([^"]+)".*/\1/'`
file=`curl --silent "https://api.github.com/repos/nccgroup/dirble/releases/latest" | grep '"name"' | grep "64-linux" | sed -E 's/.*"([^"]+)".*/\1/'`
wget "$zipfile" -O "$HOME/Downloads/$file"
# Move file to appropriate locations
unzip -q "$HOME/Downloads/$file" -d "$HOME/Downloads/"
mv "$HOME/Downloads/dirble/dirble" /usr/local/bin/
mv "$HOME/Downloads/dirble/" /usr/share/wordlists/
rm "$HOME/Downloads/$file"

(( STAGE++ ))
echo -e "\n ${BLUE}[*]${RESET} (${STAGE}/${TOTAL}) ${BOLD}Installing useful Firefox addons${RESET}"
#ToDO


#### Install Nessus ####
(( STAGE++ ))
echo -e "\n ${BLUE}[*]${RESET} (${STAGE}/${TOTAL}) ${BOLD}Installing ${BLUE}Nessus${RESET}"

#Hardcoded version number
wget -c "https://www.tenable.com/downloads/api/v1/public/pages/nessus/downloads/9745/download?i_agree_to_tenable_license_agreement=true" -O $HOME/Downloads/Nessus-8.5.1-debian6_amd64.deb
dpkg -i $HOME/Downloads/Nessus-*-debian6_amd64.deb

#Cleaning up
rm $HOME/Downloads/Nessus-*-debian6_amd64.deb
#Starting the service
systemctl start nessusd
wait 3


if [ ! -z "$nessusKey" ]; then
	/opt/nessus/sbin/nessuscli fetch --register $nessusKey
	/opt/nessus/sbin/nessusd -R
	/opt/nessus/sbin/nessus-service -D
	xdg-open https://127.0.0.1:8834/  #leave service running
else
  echo -e " ${RED}[!]${RESET} ${BOLD}Nessus license not provided!${RESET}"
  echo -e " ${YELLOW}[*]${RESET} ${BOLD}Nessus has been installed but has not been activated${RESET}"
fi

#Download latest Nessus pro for debian/kali
#echo -e "\n ${GREEN}[+]${RESET} Installing ${GREEN}nessus${RESET} ~ vulnerability scanner"
#--- Get download link
#xdg-open http://www.tenable.com/products/nessus/select-your-operating-system    *** #wget -q "http://downloads.nessus.org/<file>" -O /usr/local/src/nessus.deb   #***!!! Hardcoded version value
#dpkg -i /usr/local/src/Nessus-*-debian6_*.deb
#systemctl start nessusd
#xdg-open http://www.tenable.com/products/nessus-home
#/opt/nessus/sbin/nessus-adduser   #*** Doesn't automate
##rm -f /usr/local/src/Nessus-*-debian6_*.deb
#--- Check email
#/opt/nessus/sbin/nessuscli fetch --register <key>   #*** Doesn't automate
#/opt/nessus/sbin/nessusd -R
#/opt/nessus/sbin/nessus-service -D
#xdg-open https://127.0.0.1:8834/
#Stop the service
#systemctl disable nessusd

#### Configuring burpsuite ####
(( STAGE++ ))
echo -e "\n ${BLUE}[*]${RESET} (${STAGE}/${TOTAL}) ${BOLD}Installing ${BLUE}Burpsuite${RESET}"
if [[ "$BURP" = true ]]; then
	file="burpsuite_pro_linux*"
  common_file_locations="/root/Downloads/ $pwd /tmp"
	# Search for installer in tmp, Downloads and current directory
	for i in $(find /root/Downloads/ . /tmp -type f -name "$file"); do
		file=$i
	done

	if [ -s $file ] && [ -x $file ]; then
		echo -e " ${GREEN}[*]${RESET} ${BOLD}Burpsuite pro installer found\nProceeding with installation${RESET}"
		#Modifying the installer to shut up
		sed -i -e 's/com.install4j.runtime.installer.Installer/com.install4j.runtime.installer.Installer -q/g' $file
		sh $file

		if [[ $(dpkg -l | grep -i burpsuite) != "" ]]; then
			echo -e " ${YELLOW}[*]${RESET} ${BOLD}Burpsuite free will be uninstalled from the system.${RESET}"
			apt -q purge --auto-remove burpsuite
		else
			echo -e " ${RED}[!]${RESET}Burpsuite free not found installed.${BOLD}${RESET}"
		fi
	else
		echo -e " ${RED}[!]${RESET}Burpsuite pro installer not found.${BOLD}${RESET}"
		echo -e " ${YELLOW}[*]${RESET}Burpsuite free won't be removed${BOLD}${RESET}"
	fi
fi

#### SSH setup ####
(( STAGE++ ))
echo -e "\n ${BLUE}[*]${RESET} (${STAGE}/${TOTAL}) ${BOLD}Generating SSH keys"
# Wipe existing openssh keys
rm -f /ect/ssh/ssh_host_*
# Backup old user keys
mkdir /root/.ssh/old_keys
for file in $(find /root/.ssh/ -type f ! -name authorized_keys)
do
  mv $file /root/.ssh/old_keys/`basename $file`.old
done

# Generate new SSH keys
ssh-keygen -t ecdsa -b 521 -f /etc/ssh/ssh_host_ecdsa_key -P "" >/dev/null
ssh-keygen -o -a 100 -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -P "" >/dev/null
ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -P "" >/dev/null
ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -P "$sshPass" >/dev/null


#### Installing additional tools ####
(( STAGE++ ))
echo -e "\n ${BLUE}[*]${RESET} (${STAGE}/${TOTAL}) ${BOLD}Installing additional tools ${RESET}"
declare -a toolsList=("nbtscan-unixwiz" "rstat-client" "nfs-common" "nis" "rusers" "bloodhound" "testssl.sh" "zstd" "terminator")

# Bloodhound url http://localhost:7474

for val in ${toolsList[@]}; do
  DEBIAN_FRONTEND=noninteractive apt -y -q install $val
done


updatedb
echo -e " ${BLUE}[***]${RESET}${BOLD} Installation finished. A reboot is require to apply all changes.${RESET}\n Would you like to reboot know [Y/n]?"
