#!/bin/bash

####Update host####
apt update

####Install zsh from github####
#Using installer
sh -c "$(wget -O- https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

#Change zsh theme
ZSH_THEME="robbyrussell"

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


####Install crackmapexec from docker

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
if [[ $(service docker status) != *"active (running)"* ]]; then
	echo "starting docker service"
	docker service start
	sleep 5
fi
docker pull charliedean07/winpayloads:latest

####Init msfdb####
msfdb init


####Install SoapUI####
echo "Downloading SoapUI"
wget https://s3.amazonaws.com/downloads.eviware/soapuios/5.5.0/SoapUI-5.5.0-linux-bin.tar.gz -P ~/Downloads/

#Install SoapUI to /opt directory
echo "Installing SoapUI"
tar -xzf SoapUI-5.5.0-linux-bin.tar.gz -C /opt/
/opt/SoapUI-5.5.0/bin/testrunner.sh -r soapui-project.xml

echo "Cleaning up installation files"



####Install Firefox addons####

echo "Installing firefox addons"


####Install Nessus####
echo "Installing Nessus"

timeout 300 curl --progress -k -L -f "https://www.tenable.com/downloads/pages/60/downloads/9578/download_file?utf8=%E2%9C%93&i_agree_to_tenable_license_agreement=true&commit=I+Agree" -o "~/Downloads/" || echo -e ' '${RED}'[!]'${RESET}" Issue downloading 'Nessus'" 1>&2
dpkg -i ~/Downloads/Nessus-*-debian6_amd64.deb
sleep 20

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