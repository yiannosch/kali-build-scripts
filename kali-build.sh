#!/bin/bash


##Todo:
# 1) install burpsuite pro
# 2) activate nessus ?
# 3) install rpclient, rusers, nbtscan-unixwiz
# 4) change UI
# 5) Change background image
# 6) Generate ssh keys sshkeygen

####Get latest version####
wget -qO https://github.com/yiannosch/kali-build-scripts/blob/master/kali-build.sh && bash kali-build.sh

####--Defaults--####

####--Timezone and keyboard settings--####
keyboardApple=false       		# Using a Apple/Macintosh keyboard (non VM)?      [ --osx ]
keyboardLayout="gb"           # Set keyboard layout                             [ --keyboard gb ]
timezone="Europe/London"      # Set timezone location                           [ --timezone Europe/London ]


####--(Cosmetic) Colour output--####
RED="\033[01;31m"      # Issues/Errors
GREEN="\033[01;32m"    # Success
YELLOW="\033[01;33m"   # Warnings/Information
BLUE="\033[01;34m"     # Heading
BOLD="\033[01;01m"     # Highlight
RESET="\033[00m"       # Normal


######### Start ##########

#Check if runnign as root. Return error otherwise
if [[ ${EUID} -ne 0 ]]; then
	echo -e ' '${RED}'[!]'${RESET}" This script must be ${RED}run as root${RESET}. Quitting..." 1>&2
  exit 1
else
  echo -e " ${BLUE}[*]${RESET} ${BOLD}Kali Linux 2019.2 build script${RESET}"
fi

####Update host####
apt update

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



####Add gnome keyboard shortcuts####
#Add CTRL+ALT+T for terminal, same as Ubuntu
#Binding are hardcoded for now.
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/']"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ name "Terminal"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ command "gnome-terminal"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ binding "<CTRL><ALT>T"



####Set background wallpaper####

/usr/share/backgrounds/gnome/endless-shapes.jpg

####Install zsh from github####
#Using installer
sh -c "$(wget -O- https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

#Change zsh theme
sed -i -e 's/ZSH_THEME=.*/ZSH_THEME="robbyrussell"/g' $HOME/.zshrc

#add alias in .zshrc
echo 'alias lh="ls -lAh"\nalias la="ls -la\nalias ll="ls -l"' >> $HOME/.zshrc


####Install Sublime 3####

wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | sudo apt-key add -
sudo apt install apt-transport-https
echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list
sudo apt install sublime-text

#Sublime 3 packages to install#
cd ~/.config/sublime-text-3/Packages
#Indent XML
git clone https://github.com/alek-sys/sublimetext_indentxml.git
#HTML/CSS/JS pretify
git clone https://github.com/victorporof/Sublime-HTMLPrettify.git


####Install Atom####
wget -qO - https://packagecloud.io/AtomEditor/atom/gpgkey | sudo apt-key add -
sudo sh -c 'echo "deb [arch=amd64] https://packagecloud.io/AtomEditor/atom/any/ any main" > /etc/apt/sources.list.d/atom.list'
sudo apt install atom


####Install crackmapexec from pipenv

apt install -y libssl-dev libffi-dev python-dev build-essential
pip install --user pipenv
git clone --recursive https://github.com/byt3bl33d3r/CrackMapExec
cd CrackMapExec && pipenv install
pipenv shell
python setup.py install

#Fix .zsh path, add /root/.loca/bin to PATH
sed -i '4iexport PATH=$PATH:/root/.local/bin' $HOME/.zshrc


####Install Winpayloads####
#check if docker is running
if [[ $(systemctl status docker) != *"active (running)"* ]]; then
	echo "starting docker service"
	systemctl start docker
fi
docker pull charliedean07/winpayloads:latest

####Init msfdb####
msfdb init


####Install SoapUI####
echo "Downloading SoapUI"
wget https://s3.amazonaws.com/downloads.eviware/soapuios/5.5.0/SoapUI-5.5.0-linux-bin.tar.gz -P ~/Downloads/

#Install SoapUI to /opt directory
echo "Installing SoapUI"
tar -xzf ~/Downloads/SoapUI-5.5.0-linux-bin.tar.gz -C /opt/
/opt/SoapUI-5.5.0/bin/testrunner.sh -r soapui-project.xml

echo "Cleaning up installation files"



####Install Firefox addons####

echo "Installing firefox addons"


####Install Nessus####
echo "Installing Nessus"

curl --progress -k -L -f "https://www.tenable.com/downloads/pages/60/downloads/9578/download_file?utf8=%E2%9C%93&i_agree_to_tenable_license_agreement=true&commit=I+Agree" -o "~/Downloads/" || echo -e ' '${RED}'[!]'${RESET}" Issue downloading 'Nessus'" 1>&2
dpkg -i ~/Downloads/Nessus-*-debian6_amd64.deb

#wget "https://www.tenable.com/downloads/pages/60/downloads/9578/download_file?utf8=%E2%9C%93&i_agree_to_tenable_license_agreement=true&commit=I+Agree"

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
#--- Remove from start up
#systemctl disable nessusd
