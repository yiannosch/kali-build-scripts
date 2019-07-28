#!/bin/bash


##Todo:
# 1) install burpsuite pro
# 2) activate nessus ?
# 3) install rpclient, rusers, nbtscan-unixwiz
# 4) change UI
# 5) Change background image
# 6) Generate ssh keys sshkeygen
# 7) ZSH is asking if you want to change your default shell during installation. get rid of this???
# 8) Install blodhound + neo4j

####Get latest version####
#wget -q https://github.com/yiannosch/kali-build-scripts/blob/master/kali-build.sh && bash kali-build.sh

#test

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

#### Update OS ####
echo -e "\n $GREEN[+]$RESET Updating OS from repositories (this may take a while depending on your Internet connection & Kali version/age)"
apt -qq update && apt -y -qq full-upgrade --fix-missing
apt -y -qq autoclean && apt -y -qq autoremove


####Detect VM environment####
#Only VMware supported for now

echo -e " ${YELLOW}[i]${RESET} Identifying running environment..."
lspci | grep -i vmware && echo -e " ${YELLOW}[i]${RESET} VMware Detected."

#Remove vmware tools and install open-vm-tools if not installed.
VMTOOLS=/usr/bin/vmware-uninstall-tools.pl
if [ -f "$VMTOOLS" ]; then
	echo -e " ${YELLOW}[i]${RESET} VMwareTools found.\n nProceeding to uninstall!"
	perl /usr/bin/vmware-uninstall-tools.pl #uaser input
	#sleep 10
else
    echo -e " ${YELLOW}[i]${RESET} VMwareTools not found."
fi

if [ $(dpkg -l | grep -i open-vm-tools) == "" ]; then
	echo -e " ${YELLOW}[*]${RESET} ${BOLD}open vm tools not found on the host.\nProceeding to install${RESET}"
	apt install open-vm-tools # install open-vm-tools
	#sleep 5
fi


#Check kernel
#Find installed kernels packages
_KRL=$(dpkg -l | grep linux-image- | grep -vc meta)
if [[ "$_KRL" -gt 1 ]]; then
  echo -e "\n $YELLOW[i]$RESET Detected multiple kernels installed"
  #Remove kernel packages marked as rc
  dpkg -l | grep linux-image | grep "^rc" | cut -d " " -f 3 | xargs dpkg --purge
  KRL=$(dpkg -l | grep linux-image | grep -v meta | sort -t '.' -k 2 -g | tail -n 1 | grep "$(uname -r)")
  [[ -z "$_KRL" ]] && echo -e ' '$RED'[!]'$RESET' You are not using the latest kernel' 1>&2 && echo -e " $YELLOW[i]$RESET You have it downloaded & installed, just not using it. You need to **reboot**"
fi

#install linux headers
apt -y -qq install "linux-headers-$(uname -r)"


#### Updating hostname to preset value. If default is selected then skip ####
#echo -e "\n $GREEN[+]$RESET Updating hostname"
#Default is kali
if [ $hostname == "kali" ]; then
	echo -e " ${YELLOW}[*]${RESET} ${BOLD}Hostname is set to default.\nNo changes applied${RESET}"
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
	echo -e " ${GREEN}[*]${RESET} ${BOLD}Hostname changed. ${RESET}"
	hostname
fi

#### Configure keyboard layout ####

#--- Configure keyboard layout
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
[ -z "$timezone" ] && timezone=Etc/UTC     #Etc/GMT vs Etc/UTC vs UTC
echo "$timezone" > /etc/timezone           #Default is Europe/London
ln -sf "/usr/share/zoneinfo/$(cat /etc/timezone)" /etc/localtime



#### Gnome 3 Settings #####
echo -e " ${YELLOW}[*]${RESET} ${BOLD}Applying changes to gnome settings${RESET}"
#### Add gnome keyboard shortcuts ####
#Add CTRL+ALT+T for terminal, same as Ubuntu
#Binding are hardcoded for now.
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/']"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ name "Terminal"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ command "gnome-terminal"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ binding "<CTRL><ALT>T"

####Set background wallpaper####
#Setting wallpaper of my choice for now.
#More options will be added in a future release
gsettings set org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/gnome/endless-shapes.jpg'


#Configure gnome favourites bar
gsettings set org.gnome.shell favorite-apps "['org.gnome.Terminal.desktop', 'firefox-esr.desktop', 'org.gnome.Nautilus.desktop', 'kali-msfconsole.desktop', 'gnome-control-center.desktop', 'Burp Suite Community Edition-0.desktop', 'sublime_text.desktop', 'atom.desktop']"


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


####Install zsh from github####

#Download oh-my-zsh
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
echo 'alias lh="ls -lAh"\nalias la="ls -la"\nalias ll="ls -l"' >> $HOME/.zshrc
rm install.sh


####Install Sublime 3####

wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | sudo apt-key add -
apt install apt-transport-https
echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list
apt install sublime-text

#Sublime 3 packages to install#
cd $HOME/.config/sublime-text-3/Packages
#Indent XML
git clone https://github.com/alek-sys/sublimetext_indentxml.git
#HTML/CSS/JS pretify
git clone https://github.com/victorporof/Sublime-HTMLPrettify.git


####Install Atom####
wget -qO - https://packagecloud.io/AtomEditor/atom/gpgkey | sudo apt-key add -
sh -c 'echo "deb [arch=amd64] https://packagecloud.io/AtomEditor/atom/any/ any main" > /etc/apt/sources.list.d/atom.list'
apt install atom


#### Install crackmapexec with pipenv ####

apt install -y -qq libssl-dev libffi-dev python-dev build-essential
pip install --user pipenv
git clone --recursive https://github.com/byt3bl33d3r/CrackMapExec
cd CrackMapExec && pipenv install
pipenv shell
python setup.py install


#### Install Winpayloads ####
#check if docker is running
if [[ $(systemctl status docker) != *"active (running)"* ]]; then
	echo "starting docker service"
	systemctl start docker
fi
docker pull charliedean07/winpayloads:latest

#### Init msfdb ####
echo -e " ${YELLOW}[*]${RESET}${BOLD}Setup msfconsole${RESET}"
msfdb init
if [[ "$SHELL" == "/bin/zsh" ]]; then echo 'alias msf="msfconsole"' >> $HOME/.zshrc; fi

#Adding postgreSQL service to startup
update-rc.d postgresql enable


#### Install SoapUI ####
echo -e " ${YELLOW}[*]${RESET} ${BOLD}Downloading SoapUI${RESET}"
wget https://s3.amazonaws.com/downloads.eviware/soapuios/5.5.0/SoapUI-5.5.0-linux-bin.tar.gz -P ~/Downloads/

#Install SoapUI to /opt directory
echo -e " ${YELLOW}[*]${RESET} ${BOLD}Installing${RESET}"
tar -xzf $HOME/Downloads/SoapUI-5.5.0-linux-bin.tar.gz -C /opt/
sh /opt/SoapUI-5.5.0/bin/testrunner.sh -r soapui-project.xml


#### Install Firefox addons ####
echo -e " ${YELLOW}[*]${RESET} ${BOLD}Installing firefox addons${RESET}"
#ToDO


#### Install Nessus ####
echo -e " ${YELLOW}[*]${RESET} ${BOLD}Installing Nessus${RESET}"

#Hardcoded version number
wget -c "https://www.tenable.com/downloads/pages/60/downloads/9578/download_file?utf8=%E2%9C%93&i_agree_to_tenable_license_agreement=true&commit=I+Agree" -O $HOME/Downloads/Nessus-8.5.1-debian6_amd64.deb
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
	echo -e " ${YELLOW}[*]${RESET} ${BOLD}Nessus has been installed but has not been activated${RESET}"
	echo -e " ${RED}[*]${RESET} ${BOLD}Nessus license not provided! ${RESET}"
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

if [[ "$BURP" = true ]]; then
	file="burpsuite_pro_linux*"
	# Search for installer in tmp, Downloads and current directory
	for i in $(find /root/Downloads/ . /tmp -type f -name "$file"); do
		file=$i
	done

	if [ !file="" ]; then
		echo -e " ${GREEN}[*]${RESET} ${BOLD}Burpsuite pro installer found\nProceeding with installation${RESET}"
		sh $file
		echo -e " ${YELLOW}[*]${RESET} ${BOLD}Burpsuite free will be uninstalled from the system.${RESET}"
		apt purge --auto-remove burpsuite
	else
		echo -e " ${RED}[*]${RESET}Burpsuite pro installer not found.${BOLD}${RESET}"
		echo -e " ${YELLOW}[*]${RESET}Burpsuite free won't be removed${BOLD}${RESET}"
	fi
fi

#### SSH setup ####

# Wipe existing openssh keys
rm -f /ect/ssh/ssh_host_*
# Backup old user keys
mkdir /root/.ssh/old_keys
for file in $(find /root/.ssh/ -type f ! -name authorized_keys)
do
  mv $file /root/.ssh/old_keys/`basename $file`.old
done

# Generate new SSH keys
ssh-keygen -t ecdsa -b 521 -f /etc/ssh/ssh_host_ecdsa_key -P ""
ssh-keygen -o -a 100 -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -P ""
ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -P ""
ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -P "$sshPass"


#### Installing additional tools ####

apt install nbtscan-unixwiz  # I prefer nbtscan-unixwiz than nbtscan
apt install rstat-client
apt install nfs-common
apt install nis
apt install rusers


# Installing bloodhound

apt install bloodhound
#http://localhost:7474

updatedb
