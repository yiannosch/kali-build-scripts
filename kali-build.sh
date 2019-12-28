#!/bin/bash

##Todo:
# 1) Install blodhound + neo4j
# 2) Add firefox bookmarks (pending) useful bookmarks + nessus, bloodhound
# 3) Crete a tools folder and install more tools web, infra, web services network etc.
# 4) Install EyeWitness and GoWitness
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

####-- Get OS Architecture
OS_ARCH="$(dpkg --print-architecture)"

####-- Monitor progress --####
STAGE=0                                                           # Where are we up to
TOTAL="$( grep '(${STAGE}/${TOTAL})' $0 | wc -l;(( TOTAL-- )))"   # How many things have we got to do

####-- Other settings --####
CHECKDNS=google.com

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
#   echo -e " ${BLUE}[*]${RESET} ${BOLD}Kali Linux build script${RESET}"
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
sleep 5
export DEBIAN_FRONTEND=noninteractive
apt -q update && APT_LISTCHANGES_FRONTEND=none apt -o Dpkg::Options::="--force-confnew" -y -q full-upgrade --fix-missing
apt -y -q autoremove && apt -y -q autoclean

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

#Install linux headers
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
  #hostnamectl combines setting hostname and updating /etc/hostname
  hostnamectl set-hostname $hostname

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


####Detect desktop manager. Support for gnome and xfce for Kali 2019.4

_DMAN=$(ps -A | egrep -i "gnome|xfce")

if [[ "$_DMAN" =~ "gnome" ]]; then
    echo -e "\n ${BLUE}[INFO]${RESET} Desktop manager found Gnome ${RESET}"
elif [[ "$_DMAN" =~ "xfce" ]]; then
    echo -e "\n ${BLUE}[INFO]${RESET} Desktop manager found Xfce ${RESET}"
else
	echo -e "\n ${YELLOW}[WARN]${RESET} The desktop manager not supported. Only Gnome and Xfce supported for now...${RESET}"
fi


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
gsettings set org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/gnome/Endless-shapes.jpg'

#Configure gnome favourites bar
gsettings set org.gnome.shell favorite-apps "['org.gnome.Terminal.desktop', 'firefox-esr.desktop', 'org.gnome.Nautilus.desktop', 'kali-msfconsole.desktop', 'gnome-control-center.desktop', 'kali-burpsuite.desktop', 'sublime_text.desktop', 'atom.desktop', 'SoapUI-5.5.0-0.desktop']"

#Set theme (Kali Dark)
gsettings set org.gnome.desktop.interface gtk-theme "Kali-X-Dark"
#Set icon theme (Zen kali)
gsettings set org.gnome.desktop.interface icon-theme "Zen-Kali"
#Set power saving time (15 minutes)
gsettings set org.gnome.desktop.session idle-delay "uint32 900"
#Move dock position to the right of the screen
gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'RIGHT'
#Enable date on clock panel
dconf write /org/gnome/desktop/interface/clock-show-date "true"

#Change AltTab behaviour
gsettings set org.gnome.desktop.wm.keybindings switch-applications "['<Super>Tab']"
gsettings set org.gnome.desktop.wm.keybindings switch-windows "['<Alt>Tab']"

#Enable nano line numbering
sed -i 's/^# set linenumbers/set linenumbers/' /etc/nanorc

#### Installing additional tools ####
(( STAGE++ ))
echo -e "\n ${BLUE}[*]${RESET} (${STAGE}/${TOTAL}) ${BOLD}Installing additional tools ${RESET}"
declare -a toolsList=("nbtscan-unixwiz" "rstat-client" "nfs-common" "nis" "rusers" "bloodhound" "testssl.sh" "zstd" "terminator" "golang-go" "python3-pip")

# Bloodhound url http://localhost:7474
for val in ${toolsList[@]}; do
  DEBIAN_FRONTEND=noninteractive apt -y -q install $val
done

####Install zsh from github####
#Download oh-my-zsh
(( STAGE++ ))
echo -e "\n ${BLUE}[*]${RESET} (${STAGE}/${TOTAL}) Installing ${BLUE}zsh shell ${RESET}"

wget -q https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh
chmod +x install.sh
./install.sh --unattended
ZSH=${ZSH:-~/.oh-my-zsh}
#export SHELL="$ZSH"
# Change default shell to ZSH
chsh -s /usr/bin/zsh
#Fix .zsh path, add /root/.loca/bin to PATH
sed -i '4iexport PATH=$PATH:/root/.local/bin' $HOME/.zshrc

#Change zsh theme
sed -i -e 's/ZSH_THEME=.*/ZSH_THEME="robbyrussell"/g' $HOME/.zshrc

#add alias in .zshrc
echo -e 'alias lh="ls -lAh"\nalias la="ls -la"\nalias ll="ls -l"' >> $HOME/.zshrc
rm install.sh
chsh -s /usr/bin/zsh

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

#### Install Winpayloads ####
(( STAGE++ ))
echo -e "\n ${BLUE}[*]${RESET} (${STAGE}/${TOTAL}) Installing ${BLUE}Winpayloads ${RESET}"
# Check if docker is installed.
if [[ $(dpkg -l | grep -i docker) != "" ]]; then
  echo -e " ${GREEN}[+]${RESET} ${BOLD}Docker is already installed.${RESET}"
  # Ckeck if service is running. If not start the service
  if [[ $(systemctl status docker) != *"active (running)"* ]]; then
  	echo "${YELLOW}[i]${RESET} starting docker service"
  	systemctl start docker
  	sleep 5
  fi
else
  # Install docker from apt repositories
  apt install -y -q docker.io
  # Start the service. We know that is not running. No need to check
  systemctl start docker
  sleep 3s
fi
echo -e "${YELLOW}[i]${RESET} Pulling ${YELLOW}Docker image${RESET}..."
# Pull Winpayloads docker image
docker pull charliedean07/winpayloads:latest


#### Init msfdb ####
(( STAGE++ ))
echo -e "\n ${BLUE}[*]${RESET} (${STAGE}/${TOTAL}) msfconsole setup ${RESET}"
msfdb init
# Add alias for msfconsole in zshrc
echo 'alias msf="msfconsole"' >> $HOME/.zshrc

#Adding postgreSQL service to startup
echo -e " ${YELLOW}[i]${RESET} Enabled ${YELLOW}postgresql ${RESET}service "
update-rc.d postgresql enable


#### Install SoapUI ####
(( STAGE++ ))
echo -e "\n ${BLUE}[*]${RESET} (${STAGE}/${TOTAL}) Installing ${BLUE}SoapUI ${RESET}"
#Download the sh installer
if [ "$OS_ARCH" = "amd64" ]; then
  wget --content-disposition 'https://s3.amazonaws.com/downloads.eviware/soapuios/5.5.0/SoapUI-x64-5.5.0.sh' -P ~/Downloads/
else
  wget --content-disposition 'https://s3.amazonaws.com/downloads.eviware/soapuios/5.5.0/SoapUI-x32-5.5.0.sh' -P ~/Downloads/
fi

file=`ls /root/Downloads/SoapUI-x*.sh`
# Search for installer in tmp, Downloads and current directory
if [ -s $file ]; then
  echo -e " ${YELLOW}[i]${RESET} ${BOLD}Modifying SoapUI installer.\Proceeding with installation${RESET}"
  #Modifying the installer to shut up
  sed -i -e 's/com.install4j.runtime.installer.Installer/com.install4j.runtime.installer.Installer -q/g' $file
  sh $file
  rm "$file"
fi

#### Install Postman####
(( STAGE++ ))
if [ "$OS_ARCH" = "amd64" ]; then
  wget --content-disposition 'https://dl.pstmn.io/download/latest/linux64' -P ~/Downloads/
else
  wget --content-disposition 'https://dl.pstmn.io/download/latest/linux32' -P ~/Downloads/
fi

file=`ls /root/Downloads/Postman-linux*.tar.gz`
if [ -s "$file" ]; then
  echo -e " ${YELLOW}[i]${RESET} ${BOLD}Installing Postman${RESET}"
  tar -xzf "$file" -C /opt/
  ln -s /opt/Postman/Postman /usr/local/bin/Postman
fi

#Create directory structure to dowonload tools
(( STAGE++ ))
echo -e "\n ${BLUE}[*]${RESET} (${STAGE}/${TOTAL}) Creating tools directory"
mkdir -p -v -Z "/root/Tools/Webapp/CMS/Wordpress" "/root/Tools/Webapp/CMS/Drupal" "/root/Tools/OSINT" \
"/root/Tools/Password-cracking/wordlists" "/root/Tools/Infrastructure/Linux" "/root/Tools/Infrastructure/Windows" \
"/root/Tools/Mobile/Android" "/root/Tools/Mobile/iOS" "/root/Tools/Build-Reviews/Linux" "/root/Tools/Build-Reviews/Windows" \
"/root/Tools/BuildReviews/Mac" "/root/Tools/Configuration/Cloud/AWS" "/root/Tools/Configuration/Cloud/Azure" \
"/root/Tools/Configuration/Cloud/GCP" "/root/Tools/Configuration/Containers/Docker/" \
"/root/Tools/Configuration/Containers/Kubernetes"

####-- Install web app tools
pip install droopescan

#docker run -it --name photon
git clone https://github.com/immunIT/drupwn.git "/root/Tools/Webapp/CMS/Drupal/drupwn"
python3 /root/Tools/Webapp/CMS/Drupal/drupwn/setup.py install


####-- Install OSINT tools
#Install Photon (incredibly fast crawler designed for OSINT.)
git clone https://github.com/s0md3v/Photon.git "/root/Tools/OSINT/Photon"
docker build -t photon "/root/Tools/OSINT/Photon/"

#To execute Photon run:
#docker run -it --name photon photon:latest -u google.com
#For more info visit https://github.com/s0md3v/Photon

#Install gitrob (reconnaissance tool for GitHub organizations)
wget 'https://github.com/michenriksen/gitrob/releases/download/v2.0.0-beta/gitrob_linux_amd64_2.0.0-beta.zip' -P "/root/Tools/OSINT/"
unzip -q "/root/Tools/OSINT/gitrob_linux_amd64_2.0.0-beta.zip" -d "/root/Tools/OSINT/gitrob"
rm "/root/Tools/OSINT/gitrob_linux_amd64_2.0.0-beta.zip"
#For more info visit https://github.com/michenriksen/gitrob

#Install Sn1per Community Edition (an automated scanner that can be used during a penetration test to enumerate and scan for vulnerabilities.)
wget 'https://raw.githubusercontent.com/1N3/Sn1per/master/Dockerfile' -P "/root/Tools/OSINT/Sn1per/"
docker build -t sn1per-docker "/root/Tools/OSINT/Sn1per/"
#For more info visit https://github.com/1N3/Sn1per

#Install Sublist3r (a subdomain enumeration tool)
git clone https://github.com/aboul3la/Sublist3r.git "/root/Tools/OSINT/Sublist3r"
pip3 install -r "/root/Tools/OSINT/Sublist3r/requirements.txt"
#For more info visit https://github.com/aboul3la/Sublist3r

#Install Subfinder (a subdomain discovery tool that discovers valid subdomains for websites by using passive online sources.)
wget 'https://github.com/projectdiscovery/subfinder/releases/download/v2.2.4/subfinder-linux-amd64.tar' -P "/root/Tools/OSINT/Subfinder/"
tar -xzvf /root/Tools/OSINT/Subfinder/subfinder-linux-amd64.tar
cp /root/Tools/OSINT/Subfinder/subfinder-linux-amd64 /usr/local/bin/subfinder
#For more info visit https://github.com/projectdiscovery/subfinder

#Install dnstwist (find similar-looking domains that adversaries can use to attack you.)
git clone https://github.com/elceef/dnstwist.git "/root/Tools/OSINT/dnstwist"
cd "/root/Tools/OSINT/dnstwist" && /root/.local/bin/pipenv --three

#Install Raccoon (an offensive security tool for reconnaissance and information gathering)
pip3 install raccoon-scanner
#For more info visit https://github.com/evyatarmeged/Raccoon

#Install spiderfoot (an open source intelligence (OSINT) automation tool.)
git clone https://github.com/smicallef/spiderfoot.git "/root/Tools/OSINT/spiderfoot"
cd "/root/Tools/OSINT/spiderfoot" && /root/.local/bin/pipenv --two
#To run spiderfoot execute:
# 1) /root/.local/bin/pipenv run python sf.py
# 2) /root/.local/bin/pipenv run python sfcli.py
#For more info visit https://www.spiderfoot.net/documentation/

#ScoutSuite
#cd root/Tools/Configuration/Cloud/
#virtualenv -p python3 scoutsuite
#source scoutsuite/bin/activate
#pip install scoutsuite

file="$HOME/.local/bin/pipenv"
if [ -s "$file" ]; then
	mkdir "$HOME/Tools/Configuration/Cloud/ScoutSuite"
  cd "$HOME/Tools/Configuration/Cloud/ScoutSuite" && "$file" install && "$file" run pip3 install scoutsuite
else
	echo "${RED}[!]${RESET} Something went wrong. Installation of ${RED}${BOLD}CrackMapExec ${RESET}has failed!"
fi

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

# Start Firefox for first time, background process
firefox-esr &
sleep 3s                    # Add delay to make sure that the FF profile has been created
#--- Configure firefox
echo -e "\n ${BLUE}[*]${RESET} Installing useful${BLUE}Firefox${RESET} addons"

#--- Download extensions
ffpath="$(find ~/.mozilla/firefox/*.default*/ -maxdepth 0 -mindepth 0 -type d -name '*.default*' -print -quit)/extensions"
[ "${ffpath}" == "/extensions" ] && echo -e  "${RED}[!]${RESET} Couldn't find Firefox's config folder" 1>&2
mkdir -p "${ffpath}/"

# Wappalyzer
echo -e " ${YELLOW}[i]${RESET} Downloading ${YELLOW}${BOLD}Wappalyzer${RESET}"
timeout 300 curl --progress -k -L -f "https://addons.mozilla.org/firefox/downloads/file/3435895/wappalyzer-5.8.5-fx.xpi?src=dp-btn-primary" -o "$ffpath/wappalyzer@crunchlabz.com.xpi" || echo -e " ${RED}[!]${RESET} Issue downloading ${BOLD}Wappalyzer${RESET}" 1>&2
# Foxyproxy standard
echo -e " ${YELLOW}[i]${RESET} Downloading ${YELLOW}${BOLD}FoxyProxy standard${RESET}"
timeout 300 curl --progress -k -L -f "https://addons.mozilla.org/firefox/downloads/file/3466053/foxyproxy_standard-7.4.2-an+fx.xpi?src=dp-btn-primary" -o "$ffpath/foxyproxy@eric.h.jung.xpi" || echo -e " ${RED}[!]${RESET} Issue downloading ${BOLD}FoxyProxy standard${RESET}" 1>&2
# Cookies and headers analyser
echo -e " ${YELLOW}[i]${RESET} Downloading ${YELLOW}${BOLD}Cookies and headers analyser${RESET}"
timeout 300 curl --progress -k -L -f "https://addons.mozilla.org/firefox/downloads/file/858681/cookies_and_http_headers_analyser-2.6-an+fx-linux.xpi?src=dp-btn-primary" -o "$ffpath/{637ac5a9-47b3-475b-b724-f455f5a56897}.xpi" || echo -e " ${RED}[!]${RESET} Issue downloading ${BOLD}Cookies and HTTP headers analyser${RESET}" 1>&2
# Web developer toolbar
echo -e " ${YELLOW}[i]${RESET} Downloading ${YELLOW}${BOLD}Web developer toolbar${RESET}"
timeout 300 curl --progress -k -L -f "https://addons.mozilla.org/firefox/downloads/file/3470301/web_developer-2.0.4-an+fx.xpi?src=dp-btn-primary" -o "$ffpath/{c45c406e-ab73-11d8-be73-000a95be3b12}.xpi" || echo -e " ${RED}[!]${RESET} Issue downloading ${BOLD}Web developer toolbar${RESET}" 1>&2
# Cookie quick manager
echo -e " ${YELLOW}[i]${RESET} Downloading ${YELLOW}${BOLD}Cookie quick manager${RESET}"
timeout 300 curl --progress -k -L -f "https://addons.mozilla.org/firefox/downloads/file/3343599/cookie_quick_manager-0.5rc2-an+fx.xpi?src=dp-btn-primary" -o "$ffpath/{60f82f00-9ad5-4de5-b31c-b16a47c51558}.xpi" || echo -e " ${RED}[!]${RESET} Issue downloading ${BOLD}Cookie quick manager{RESET}" 1>&2
# React developer tools
echo -e " ${YELLOW}[i]${RESET} Downloading ${YELLOW}${BOLD}React developer tools${RESET}"
timeout 300 curl --progress -k -L -f "https://addons.mozilla.org/firefox/downloads/file/3472587/react_developer_tools-4.3.0-fx.xpi?src=dp-btn-primary" -o "$ffpath/@react-devtools.xpi" || echo -e " ${RED}[!]${RESET} Issue downloading ${BOLD}React developer tools${RESET}" 1>&2

#--- Installing extensions
for FILE in $(find "${ffpath}" -maxdepth 1 -type f -name '*.xpi'); do
  d="$(basename "$FILE" .xpi)"
  mkdir -p "${ffpath}/${d}/"
  unzip -q -o -d "${ffpath}/${d}/" "$FILE"
  rm -f "$FILE"
done

#Generate random key to use for foxyproxy configuration
function random_key() {
 od -A n -t u -N 4 /dev/urandom
}


# Kill firefox processes gracefully!
kill -s SIGTERM $(ps -e | grep firefox-esr | awk '{print $1}')
sleep 3s

#Enable plugins
FILE=$(find ~/.mozilla/firefox/*.default*/ -maxdepth 1 -type f -name 'extensions.json' -print -quit)
if [ ! -e "$FILE" ] || [ -z "$FILE" ]; then
  echo -e " ${RED}[!]${RESET}${BOLD} extensions.js${RESET} not found! "
else
  echo -e " ${GREEN}[+]${RESET} Enabled ${GREEN}Firefox's extensions${RESET} "
  sed -i 's/"active":false,/"active":true,/g' "$FILE"                # Force them all!
  sed -i 's/"userDisabled":true,/"userDisabled":false,/g' "$FILE"    # Force them all!
fi

# Enable addons. Firefox must be closed.
FILE=$(find ~/.mozilla/firefox/*.default*/ -maxdepth 1 -type f -name 'prefs.js' -print -quit)
if [ ! -e "$FILE" ] || [ -z "$FILE" ]; then
  echo -e " ${RED}[!]${RESET}${BOLD} prefs.js${RESET} not found! "
else
  echo 'user_pref("extensions.autoDisableScopes", 14);' >> "$FILE"
fi

# Restarting Firfox
echo -e " ${YELLOW}[i]${RESET} Restarting Firefox..."
timeout 8 firefox >/dev/null 2>&1
sleep 3s

# Configure Foxyproxy
FILE=$(find ~/.mozilla/firefox/*.default*/ -maxdepth 1 -type f -name 'storage-sync.sqlite')
if [ ! -e "$FILE" ] || [ -z "$FILE" ]; then
  echo -e " ${RED}[!]${RESET}Something went wrong with the${RED}${BOLD} FoxyProxy${RESET} Firefox extension (did any extensions install?).\n Skipping..." 1>&2
else
  # Flash the db. This will delete any existing entries
  echo -e " ${YELLOW}[i]${RESET} Configuring FoxyProxy settings "

  # backup old db and clean database
  cp -n "$FILE"{,.buk} && sqlite3 "$FILE" "DELETE FROM collection_data WHERE record_id LIKE 'key-%'"

  #Try to generate a random key value rather using hardcoded values
  fp_key1=$(random_key | sed -e 's/^[[:space:]]*//')
  fp_key2=$(random_key | sed -e 's/^[[:space:]]*//')
  fp_key3=$(random_key | sed -e 's/^[[:space:]]*//')
  fp_key4=$(random_key | sed -e 's/^[[:space:]]*//')

  #Insert proxy settings to db
  sqlite3 "$FILE" "INSERT into collection_data(collection_name, record_id, record) VALUES ('default/foxyproxy@eric.h.jung','key-$fp_key1', '{\"id\":\"$fp_key1\",\"key\":\"$fp_key1\",\"data\":{\"title\":\"localhost 8080\",\"type\":1,\"color\":\"#1a14cc\",\"address\":\"127.0.0.1\",\"port\":8080,\"active\":true,\"whitePatterns\":[{\"title\":\"all URLs\",\"active\":true,\"pattern\":\"*\",\"type\":1,\"protocols\":1}],\"blackPatterns\":[{\"title\":\"local hostnames (usually no dots in the name). Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?(?:localhost|127\\\\.\\\\d+\\\\.\\\\d+\\\\.\\\\d+)(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1},{\"title\":\"local subnets (IANA reserved address space). Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?(?:192\\\\.168\\\\.\\\\d+\\\\.\\\\d+|10\\\\.\\\\d+\\\\.\\\\d+\\\\.\\\\d+|172\\\\.(?:1[6789]|2[0-9]|3[01])\\\\.\\\\d+\\\\.\\\\d+)(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1},{\"title\":\"localhost - matches the local host optionally prefixed by a user:password authentication string and optionally suffixed by a port number. The entire local subnet (127.0.0.0/8) matches. Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?[\\\\w-]+(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1}],\"index\":0},\"_status\":\"created\"}'); INSERT into collection_data(collection_name, record_id, record) VALUES ('default/foxyproxy@eric.h.jung','key-$fp_key2', '{\"id\":\"key-$fp_key2\",\"key\":\"$fp_key2\",\"data\":{\"title\":\"localhost 8081\",\"type\":1,\"color\":\"#66cc66\",\"address\":\"127.0.0.1\",\"port\":8081,\"active\":true,\"whitePatterns\":[{\"title\":\"all URLs\",\"active\":true,\"pattern\":\"*\",\"type\":1,\"protocols\":1}],\"blackPatterns\":[{\"title\":\"local hostnames (usually no dots in the name). Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?(?:localhost|127\\\\.\\\\d+\\\\.\\\\d+\\\\.\\\\d+)(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1},{\"title\":\"local subnets (IANA reserved address space). Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?(?:192\\\\.168\\\\.\\\\d+\\\\.\\\\d+|10\\\\.\\\\d+\\\\.\\\\d+\\\\.\\\\d+|172\\\\.(?:1[6789]|2[0-9]|3[01])\\\\.\\\\d+\\\\.\\\\d+)(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1},{\"title\":\"localhost - matches the local host optionally prefixed by a user:password authentication string and optionally suffixed by a port number. The entire local subnet (127.0.0.0/8) matches. Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?[\\\\w-]+(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1}],\"index\":1},\"_status\":\"created\"}'); INSERT into collection_data(collection_name, record_id, record) VALUES ('default/foxyproxy@eric.h.jung','key-$fp_key3', '{\"id\":\"key-$fp_key3\",\"key\":\"$fp_key3\",\"data\":{\"title\":\"localhost 8069\",\"type\":1,\"color\":\"#ccac2a\",\"address\":\"127.0.0.1\",\"port\":8069,\"active\":true,\"whitePatterns\":[{\"title\":\"all URLs\",\"active\":true,\"pattern\":\"*\",\"type\":1,\"protocols\":1}],\"blackPatterns\":[{\"title\":\"local hostnames (usually no dots in the name). Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?(?:localhost|127\\\\.\\\\d+\\\\.\\\\d+\\\\.\\\\d+)(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1},{\"title\":\"local subnets (IANA reserved address space). Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?(?:192\\\\.168\\\\.\\\\d+\\\\.\\\\d+|10\\\\.\\\\d+\\\\.\\\\d+\\\\.\\\\d+|172\\\\.(?:1[6789]|2[0-9]|3[01])\\\\.\\\\d+\\\\.\\\\d+)(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1},{\"title\":\"localhost - matches the local host optionally prefixed by a user:password authentication string and optionally suffixed by a port number. The entire local subnet (127.0.0.0/8) matches. Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?[\\\\w-]+(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1}],\"index\":2},\"_status\":\"created\"}'); INSERT into collection_data(collection_name, record_id, record) VALUES ('default/foxyproxy@eric.h.jung','key-$fp_key4', '{\"id\":\"$fp_key4\",\"key\":\"$fp_key4\",\"data\":{\"title\":\"localhost 6969\",\"type\":1,\"color\":\"#c730cc\",\"address\":\"127.0.0.1\",\"port\":6969,\"active\":true,\"whitePatterns\":[{\"title\":\"all URLs\",\"active\":true,\"pattern\":\"*\",\"type\":1,\"protocols\":1}],\"blackPatterns\":[{\"title\":\"local hostnames (usually no dots in the name). Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?(?:localhost|127\\\\.\\\\d+\\\\.\\\\d+\\\\.\\\\d+)(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1},{\"title\":\"local subnets (IANA reserved address space). Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?(?:192\\\\.168\\\\.\\\\d+\\\\.\\\\d+|10\\\\.\\\\d+\\\\.\\\\d+\\\\.\\\\d+|172\\\\.(?:1[6789]|2[0-9]|3[01])\\\\.\\\\d+\\\\.\\\\d+)(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1},{\"title\":\"localhost - matches the local host optionally prefixed by a user:password authentication string and optionally suffixed by a port number. The entire local subnet (127.0.0.0/8) matches. Pattern exists because ''Do not use this proxy for localhost and intranet/private IP addresses'' is checked.\",\"active\":true,\"pattern\":\"^(?:[^:@/]+(?::[^@/]+)?@)?[\\\\w-]+(?::\\\\d+)?(?:/.*)?$\",\"type\":2,\"protocols\":1}],\"index\":3},\"_status\":\"created\"}');" ".exit"
fi


#### Install Nessus ####
(( STAGE++ ))
echo -e "\n ${BLUE}[*]${RESET} (${STAGE}/${TOTAL}) ${BOLD}Installing ${BLUE}Nessus${RESET}"
if [ "$OS_ARCH" = "amd64" ]; then
  wget --content-disposition 'https://www.tenable.com/downloads/api/v1/public/pages/nessus/downloads/10190/download?i_agree_to_tenable_license_agreement=true' -P ~/Downloads/
else
  wget --content-disposition 'https://www.tenable.com/downloads/api/v1/public/pages/nessus/downloads/10191/download?i_agree_to_tenable_license_agreement=true' -P ~/Downloads/
fi

file=`ls /root/Downloads/Nessus-*.deb`
if [ -s "$file" ]; then
  dpkg -i "$file"
  sleep 2
  #Cleaning up
  rm "$file"
  #Starting the service
  systemctl start nessusd
  sleep 3
fi

if [ -f "/opt/nessus/sbin/nessuscli" ]; then
  if [ ! -z "$nessusKey" ]; then
  	/opt/nessus/sbin/nessuscli fetch --register $nessusKey
  	/opt/nessus/sbin/nessusd -R
  	/opt/nessus/sbin/nessus-service -D
  	xdg-open https://127.0.0.1:8834/
  else
    echo -e " ${YELLOW}[*]${RESET} ${BOLD}Nessus has been installed but has not been activated${RESET}"
    echo -e " ${RED}[!]${RESET} ${BOLD}A Nessus license was not provided!${RESET}"
  fi
else
  echo -e " ${RED}[*]${RESET} ${BOLD}Oops! Something went wrong. ${RED}${BOLD}Nessus has not been installed${RESET}"
fi


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
mkdir -p /root/.ssh/old_keys/
for file in $(find /root/.ssh/ -type f ! -name authorized_keys)
do
  mv $file /root/.ssh/old_keys/`basename $file`.old
done

# Generate new SSH keys
ssh-keygen -t ecdsa -b 521 -f /etc/ssh/ssh_host_ecdsa_key -P "" >/dev/null
ssh-keygen -o -a 100 -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -P "" >/dev/null
ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -P "" >/dev/null
ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -P "$sshPass" >/dev/null


updatedb
echo -e " ${BLUE}[***]${RESET}${BOLD} Installation finished. A reboot is require to apply all changes.${RESET}\n Would you like to reboot know [Y/n]?"
IFS=''
while true
do
  read -s -n 1 key
  if [ "$key" = "y" ]; then
    echo -e " ${YELLOW}[i]${RESET}${BOLD} Your PC will reboot now!${RESET}"
    sleep 3
    reboot
  elif [ "$key" = "n" ]; then
    echo -e "${GREEN}${BOLD} Goodbye!!${RESET}"
    break
  elif [ "$key" = "" ]; then
    echo -e " ${YELLOW}[i]${RESET}${BOLD} Your PC will reboot now!${RESET}"
    sleep 3
    reboot
  fi
done
