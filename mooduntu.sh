#! /bin/bash
clear
read -p "The script is doing multiple 'sudo apt-get install XXX', it needs your root password. "

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

# Git
sudo apt-get --assume-yes install git

mkdir ~/Sites

# Clone the user private moodle repository fork
# It will trigger a request to the passphrase
git clone $GITHUBACCOUNT ~/Sites/Moodle_HEAD

### We are now done asking anything to the user###

# Update ubuntu
sudo apt-get --assume-yes update
sudo apt-get --assume-yes upgrade

# Vim
sudo apt-get --assume-yes install vim

# Git
sudo apt-get --assume-yes install git
git config --global color.ui true

# Apache2
sudo apt-get --assume-yes install apache2

# Mysql - set the password to 'moodle'
# Note: the export and the last line setting empty password should not be necessary,
# the two echo should be enough to 
# create a cleartext copy of 'moodle' password in /var/cache/debconf/passwords.dat 
# (which is normally only readable by root and the password will be deleted by the
# package management system after the successfull installation of the mysql-server 
# package).
export DEBIAN_FRONTEND=noninteractive
echo mysql-server mysql-server/root_password password moodle | sudo debconf-set-selections
echo mysql-server mysql-server/root_password_again password moodle | sudo debconf-set-selections
sudo apt-get -q -y install mysql-server
mysql -uroot -p'moodle' -e "CREATE DATABASE moodle_HEAD"
mysql -uroot -p'moodle' -e "CREATE DATABASE moodle_23"
mysql -uroot -p'moodle' -e "CREATE DATABASE moodle_22"
mysql -uroot -p'moodle' -e "ALTER DATABASE moodle_HEAD DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci"
mysql -uroot -p'moodle' -e "ALTER DATABASE moodle_23 DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci"
mysql -uroot -p'moodle' -e "ALTER DATABASE moodle_22 DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci"

# PHP
sudo apt-get --assume-yes install php5
sudo apt-get --assume-yes install php5-mysql php5-curl php5-gd php5-intl php5-xmlrpc

# Restart apache
sudo service apache2 restart

# Install full mooduntu
git clone git://github.com/mouneyrac/mooduntu.git ~/Documents/mooduntu

# Moodle Dev Kit
git clone git://github.com/FMCorz/mdk.git ~/Documents/MoodleDevKit
chmod +x ~/Documents/MoodleDevKit/moodle
chmod +x ~/Documents/MoodleDevKit/moodle-*.py
sudo ln -s ~/Documents/MoodleDevKit/moodle /usr/local/bin
cp ~/Documents/MoodleDevKit/config-dist.json ~/Documents/MoodleDevKit/config.json

# Create a folder available from /var/www
sudo ln -s ~/Sites /var/www/Sites

# Create moodledata dir
sudo mkdir /home/www-data
sudo mkdir /home/www-data/moodledata
sudo chmod -R 0770 /home/www-data/moodledata
sudo chown -R www-data /home/www-data

# Setup Moodle Dev Kit
#FILE=$HOME"/Documents/MoodleDevKit/config.json"
#sed -i 's/"www": "\/var\/www"/"www": "\/var\/www\/Sites"/' $FILE


# Install Moodle instances
cd ~/Sites/Moodle_HEAD
git remote add upstream git://git.moodle.org/moodle.git
git fetch upstream

# Moodle 23
cp -r ~/Sites/Moodle_HEAD ~/Sites/Moodle_23
cd ~/Sites/Moodle_23
git checkout -b MOODLE_23_STABLE origin/MOODLE_23_STABLE
git pull upstream MOODLE_23_STABLE
sudo /usr/bin/php ~/Sites/Moodle_23/admin/cli/install.php --wwwroot=http://localhost/Sites/Moodle_23 --dataroot=/home/www-data/moodledata/moodledata_23 --dbname=moodle_23 --dbpass=moodle --dbsocket --fullname="Moodle 23" --shortname=Moodle23 --adminpass=Admin2012! --non-interactive --agree-license --allow-unstable
sudo chmod 755 ~/Sites/Moodle_23/config.php

# Moodle 22
cp -r ~/Sites/Moodle_HEAD ~/Sites/Moodle_22
cd ~/Sites/Moodle_22
git checkout -b MOODLE_22_STABLE origin/MOODLE_22_STABLE
git pull upstream MOODLE_22_STABLE
sudo /usr/bin/php ~/Sites/Moodle_22/admin/cli/install.php --wwwroot=http://localhost/Sites/Moodle_22 --dataroot=/home/www-data/moodledata/moodledata_22 --dbname=moodle_22 --dbpass=moodle --dbsocket --fullname="Moodle 22" --shortname=Moodle22 --adminpass=Admin2012! --non-interactive --agree-license --allow-unstable
sudo chmod 755 ~/Sites/Moodle_22/config.php

# Back to Moodle HEAD
cd ~/Sites/Moodle_HEAD
git pull upstream master
sudo /usr/bin/php ~/Sites/Moodle_HEAD/admin/cli/install.php --wwwroot=http://localhost/Sites/Moodle_HEAD --dataroot=/home/www-data/moodledata/moodledata_HEAD --dbname=moodle_HEAD --dbpass=moodle --dbsocket --fullname="Moodle HEAD" --shortname=MoodleHEAD --adminpass=Admin2012! --non-interactive --agree-license --allow-unstable
sudo chmod 755 ~/Sites/Moodle_HEAD/config.php

# Install Netbeans
sudo apt-get -y install netbeans

