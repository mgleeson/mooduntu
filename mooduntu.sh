#! /bin/bash
clear

read -p "The script is doing multiple 'sudo apt-get install XXX', it needs your root password. "

# Add a specific hostname
# Note: you will need to add it on your host
# check this VM ip with ifconfig (on virtualbox change the adpater network for bridged - the IP should something like 10.1.1.XX). Then in your host machine add mooduntu.local 10.1.1.XX in the right file (unix => /etc/hosts)
sudo chmod 777 /etc/hosts
sudo echo '127.0.0.1 mooduntu.local' >> /etc/hosts
sudo chmod 644 /etc/hosts 

# Create the main folder for the Moodle sites
mkdir ~/Sites

# Add samba server
# On Windows 8 go to /Windows/System32/Drivers/etc/hosts and add 10.X.X.X mooduntu.local
# Then click right on Network in the file explorer. Add a network drive \\mooduntu.local\moodle
sudo apt-get -y install samba smbfs
sudo chmod 777 /etc/samba/smb.conf
sudo echo '' >> /etc/samba/smb.conf
sudo echo 'netbios name = mooduntu.local' >> /etc/samba/smb.conf
sudo echo '' >> /etc/samba/smb.conf
sudo echo 'security = user' >> /etc/samba/smb.conf
sudo echo '' >> /etc/samba/smb.conf
sudo echo '[moodle]' >> /etc/samba/smb.conf
sudo echo '    comment = Moodle sites' >> /etc/samba/smb.conf
sudo echo "    path = $HOME/Sites" >> /etc/samba/smb.conf
sudo echo '    guest ok = yes' >> /etc/samba/smb.conf
sudo echo '    browseable = yes' >> /etc/samba/smb.conf
sudo echo '    read only = no' >> /etc/samba/smb.conf
sudo echo '    create mask = 0777' >> /etc/samba/smb.conf
sudo echo '    directory mask = 0777' >> /etc/samba/smb.conf
sudo echo '    force create mode = 777' >> /etc/samba/smb.conf
sudo echo '    force directory mode = 777' >> /etc/samba/smb.conf
sudo echo '    force security mode = 777' >> /etc/samba/smb.conf
sudo echo '    force directory security mode = 777' >> /etc/samba/smb.conf
sudo echo '    writable = yes' >> /etc/samba/smb.conf
sudo chmod 644 /etc/samba/smb.conf
# Create and add samba user
clear
WHOAMI=`whoami`
echo "You need to create a samba password for yourself ('$WHOAMI')"
sudo smbpasswd -a $WHOAMI
sudo smbpasswd -e $WHOAMI
sudo smbd reload
sudo restart smbd
sudo restart nmbd

# Curl
sudo apt-get install -y curl

clear
echo "You MUST have a Github.com account. Go to create one if haven't. This script forks the moodle repository on Github.com, if you haven't done it. Then this script adds a new SSH key to you github account so you can push directly from this VM without entering your password once the script has ran. Your login/password will only be used to do SSL curl call - even thought the script is carefully tested to not have any bug, the script contributors or distributors CANNOT be hold reponsible for the script updating/deleting your Github rep and Github account."
read -p "Github username:" githubuser
# Do not display the password
stty -echo
read -p "Github password:" githubpassword; echo
stty echo
# Retrieve user email address (in order to create SSH key)
GETEMAIL=`curl -u "$githubuser:$githubpassword" -i https://api.github.com/user/emails | grep -Po '\[*"([^""]*)"' | tail -1`
EMAIL=${GETEMAIL//\"/}
# Fork moodle.git if not already done
FORK=`curl -u "$githubuser:$githubpassword" -i https://api.github.com/repos/$githubuser/moodle | grep https://github.com/moodle/moodle.git`
if [ -z "$FORK" ]; then
    # Fork the moodle rep: asynchronous
    # TODO before cloning check the fork has been done (even thought it's extremly rare it does not happen before)
    curl  -u "$githubuser:$githubpassword" -X POST -i https://api.github.com/repos/moodle/moodle/forks
fi

# Set GITHUBACCOUNT variable
GITHUBACCOUNT="git@github.com:$githubuser/moodle.git"
# TODO support non github account, default: GITHUBACCOUNT="git://github.com/moodle/moodle.git"
read -p "Enter your Github SSH passphrase - you will be prompt to enter it a second time very soon" githubpassphrase
# Create SSH key (by default there is none in Ubuntu)
ssh-keygen -f ~/.ssh/id_rsa -N "$githubpassphrase" -t rsa -C "$EMAIL"

# Send SSH key to github
# TODO detect multiple mooduntu keys and offer to delete previous ones
sshkey=`cat ~/.ssh/id_rsa.pub`
jsonparams="{\"title\":\"mooduntu ssh key\", \"key\":\"$sshkey\"}"
curl -X POST -u "$githubuser:$githubpassword" -d "$jsonparams" -i https://api.github.com/user/keys

# Don't ask for SSH confirm when adding an host
echo 'StrictHostKeyChecking no' > ~/.ssh/config

# SSH attempt to trigger the passphrase request
ssh -T git@github.com

### We are now done asking anything to the user###

# Update ubuntu
sudo apt-get --assume-yes update
sudo apt-get --assume-yes upgrade

# Vim
sudo apt-get --assume-yes install vim

# Git
sudo apt-get --assume-yes install git
git config --global color.ui true
git config --global user.email $EMAIL

# Tig
sudo apt-get -y install tig

# Apache2
sudo apt-get --assume-yes install apache2

# Mysql - set the password to 'moodle'
# create a cleartext copy of 'moodle' password in /var/cache/debconf/passwords.dat 
# (which is normally only readable by root and the password will be deleted by the
# package management system after the successfull installation of the mysql-server 
# package).
export DEBIAN_FRONTEND=noninteractive
echo mysql-server mysql-server/root_password password moodle | sudo debconf-set-selections
echo mysql-server mysql-server/root_password_again password moodle | sudo debconf-set-selections
sudo apt-get -q -y install mysql-server

# PHP
sudo apt-get --assume-yes install php5
sudo apt-get --assume-yes install php5-mysql php5-curl php5-gd php5-intl php5-xmlrpc

# Postgres
sudo apt-get -y install postgresql php5-pgsql
sudo service postgresql start
sudo -u postgres psql -c"ALTER user postgres WITH PASSWORD 'moodle'"
sudo service postgresql restart

# Restart apache
sudo service apache2 restart

# Create a folder available from /var/www
sudo ln -s ~/Sites /var/www/Sites

# Install full mooduntu
git clone git://github.com/mouneyrac/mooduntu.git ~/Documents/mooduntu

# Install PHPunit
sudo apt-get -y install php-pear
sudo pear upgrade
sudo pear config-set auto_discover 1
sudo pear channel-discover pear.phpunit.de
sudo pear install pear.phpunit.de/PHPUnit
sudo pear install phpunit/DbUnit

# Moodle Dev Kit
git clone git://github.com/FMCorz/mdk.git ~/Documents/MoodleDevKit
chmod +x ~/Documents/MoodleDevKit/moodle
chmod +x ~/Documents/MoodleDevKit/moodle-*.py
sudo ln -s ~/Documents/MoodleDevKit/moodle /usr/local/bin
cp ~/Documents/MoodleDevKit/config-dist.json ~/Documents/MoodleDevKit/config.json

# Setup Moodle Dev Kit
moodle config set remotes.mine $GITHUBACCOUNT
moodle config set dirs.storage $HOME/Sites
moodle config set dirs.moodle $HOME/.moodle
moodle config set host mooduntu.local
moodle config set db.mysqli.passwd moodle
moodle config set db.pgsql.user postgres
moodle config set db.pgsql.passwd moodle
# MDK require write access on /var/www
sudo chmod 777 /var/www

# Create Moodle HEAD
moodle create --version master
cd ~/Sites/stablemaster/moodle
moodle install
moodle phpunit

# Create Moodle HEAD for postgres
moodle create --version master --engine pgsql -s pg --install
cd ~/Sites/stablemaster_pg/moodle
moodle phpunit

# Create Moodle 23 Stable
moodle create --version 23
cd ~/Sites/stable23/moodle
moodle install
moodle phpunit

# Create Moodle 22 Stable
moodle create --version 22
cd ~/Sites/stable22/moodle
moodle install

# Install Java JRE 7
#sudo apt-get -y install openjdk-7-jre

# Install Netbeans for PHP
#wget http://download.netbeans.org/netbeans/7.2/final/bundles/netbeans-7.2-ml-php-linux.sh -O /tmp/netbeans-linux.sh
#echo "Installing Netbeans 7.2, please wait..."
#sudo bash /tmp/netbeans-linux.sh --silent
#sudo ln -s /usr/local/netbeans-7.2/bin/netbeans /usr/local/bin/netbeans

# Chrome
#wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
#sudo sh -c 'echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'
#sudo apt-get update 
#sudo apt-get install -y google-chrome-stable

