#! /bin/bash
clear

read -p "The script is doing multiple 'sudo apt-get install XXX', it needs your root password. "
read -p "What's your fullname (it will be displayed in the git commits)" gitfullname

clear

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
read -p "Enter your Github SSH passphrase (you will be prompt to enter it a second time very soon):" githubpassphrase
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
git config --global user.name "$gitfullname"


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

# Install PHPunit
sudo apt-get -y install php-pear
sudo pear upgrade
sudo pear config-set auto_discover 1

# Moodle Dev Kit
cd /opt
sudo git clone git://github.com/FMCorz/mdk.git moodle-sdk
sudo chmod +x /opt/moodle-sdk/mdk.py
sudo ln -s /opt/moodle-sdk/mdk.py /usr/local/bin/mdk
mkdir ~/www
sudo ln -s ~/www /var/www/m
clear
read -p  "Initialising mdk - Select all default except MySQL (root/moodle) and Postgresql (postgres/moodle) username/password. Press [Enter] to continue." continuethescript
sudo mdk init
cd ~

# Install Moodle development version (master)
mdk create --engine pgsql --version master --install

