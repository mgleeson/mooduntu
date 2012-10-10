#! /bin/bash
clear
echo "The script is going to \"sudo apt-get install\" everywhere"

# Update ubuntu
sudo apt-get --assume-yes update
sudo apt-get --assume-yes upgrade

# Vim
sudo apt-get --assume-yes install vim

# Git
sudo apt-get --assume-yes install git

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
#sudo mysqladmin -u root password moodle

# PHP
sudo apt-get --assume-yes install php5
sudo apt-get --assume-yes install php5-curl php5-gd php5-intl php5-xmlrpc

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
mkdir ~/Sites
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

# Install Netbeans
sudo apt-get -y install netbeans

