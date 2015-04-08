# Data Science Toolkit - Street 2 Coordinates
This repo extracts the `street2coordinates` endpoint from the [Data Science Toolkit](http://www.datasciencetoolkit.org/). The Data Science Toolkit has a ton of functionality, but I'm only interested in the `street2coordinates` functionality.

## Digital Ocean Installation
These instructions cover how to setup the project to run on a Digital Ocean server that only costs $5 a month.

There's two parts to the installation process. The first part is to build the database that will be used to map an address to its coordinates. And the second part is to setup the web server.


### Building the Database
To build the database, we'll create a temporary server because it needs more space and CPU. Once we have created the database, we can copy the database to a smaller server.

#### Create a VPS and Login
Create a server with 2 Gb of memory and 40 Gb of hard disk space. Then login as the root user. We won't worry about securing the server because we will throw it away after we have finished building the database.

#### Setup the Server
Run the following commands from the command line as the root user.

Setup 4 gig swap that's needed when building the database indexes
```
sudo install -o root -g root -m 0600 /dev/null /swapfile
dd if=/dev/zero of=/swapfile bs=1k count=4096k
mkswap /swapfile
swapon /swapfile
echo "/swapfile       swap    swap    auto      0       0" | sudo tee -a /etc/fstab
sudo sysctl -w vm.swappiness=10
echo vm.swappiness = 10 | sudo tee -a /etc/sysctl.conf
```

Update and install needed software packages
```
sudo apt-get update
sudo apt-get install -y build-essential sqlite3 libsqlite3-dev flex bison unzip lftp git ruby ruby1.9.1-dev
sudo gem install sqlite3 text
```

Download and install the geocoder gem
```
git clone https://github.com/geocommons/geocoder.git
cd geocoder
make
sudo make install
```

Download the tiger/line data and build the database. This can take hours. Be sure to change the `TIGER2014` directory to the most recent year's directory. It's usually a year behind.

There's over 13 Gb of data to download, so it will take a while.
```
cd /opt
sudo mkdir tiger
cd tiger
sudo lftp ftp://ftp2.census.gov -e 'mirror /geo/tiger/TIGER2014/EDGES/ . --parallel=5 && exit'
sudo lftp ftp://ftp2.census.gov -e 'mirror /geo/tiger/TIGER2014/FEATNAMES/ . --parallel=5 && exit'
sudo lftp ftp://ftp2.census.gov -e 'mirror /geo/tiger/TIGER2014/ADDR/ . --parallel=5 && exit'
```

Now let's build the database from the TIGER data
```
# this will take a few hours, so use linux's screen app
# so you can detach and it will still run
screen
# you can detach anytime with ctrl-a + d
# and re-attach with screen -r

# import the data (will take a couple hours)
cd ~/geocoder
mkdir data
cd build
./tiger_import ../data/geocode.db /opt/tiger/

# rebuild metaphones (will take a few seconds)
cd ..
sudo bin/rebuild_metaphones data/geocode.db

# build the indexes (will take a few hours)
chmod +x build/build_indexes
build/build_indexes data/geocode.db
```

And now we're done building the datase. It's located at   /home/root/geocoder/data/geocode.db`  We'll copy this database to the web server that we build next.

### Building the Webserver
The following instructions cover how to setup the webserver. These instructions cover how to harden the security on the webserver, but I do not claim that these are the absolute best security procedures. They provide pretty good security, but feel free to make any security adjustments you see fit.

Create an Ubuntu server with 512 Mb memory and login as root.

Update the server
```
apt-get update
apt-get install -y ferm build-essential sqlite3 libsqlite3-dev flex bison unzip git ruby fail2ban nginx libssl-dev unattended-upgrades

```

Add a new user called `dstk`. This user will be used to install the app and also run the web server
```
adduser dstk

# add the user to the sudo group
usermod -a -G sudo dstk
```

Add your public key to the dstk user so you can login without a password.
```
su - dstk
vim ~/.ssh/authorized_keys
```

Update SSH to not allow root login nor password
```
sudo vim /etc/ssh/sshd_config
# within the file
- PermitRootLogin no
- PasswordAuthentication no
- AllowUsers dstk

# restart ssh
sudo service ssh restart
```

Now keep your current terminal open and confirm you can login from another terminal with the deployer user. If you can't then fix the sshd_config file before proceeding.

Setup the firewall rules to only allow ssh and http connections to the server
```
# copy and paste the following to: /etc/ferm/ferm.etc
table filter {
    chain INPUT {
        policy DROP;

        # connection tracking
        mod state state INVALID DROP;
        mod state state (ESTABLISHED RELATED) ACCEPT;

        # allow local packet
        interface lo ACCEPT;

        # allow SSH and HTTP connections
        proto tcp dport (ssh http) ACCEPT;
    }
    chain OUTPUT {
        policy ACCEPT;

        # connection tracking
        #mod state state INVALID DROP;
        mod state state (ESTABLISHED RELATED) ACCEPT;
    }
    chain FORWARD {
        policy DROP;

        # connection tracking
        mod state state INVALID DROP;
        mod state state (ESTABLISHED RELATED) ACCEPT;
    }
}
```

Save the file and then restart ferm: `sudo service ferm restart`

Configure fail2ban
```
# copy the example config file to start from
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo vim /etc/fail2ban/jail.local
# make the following changes to the file
- ssh jail is enabled by default
- enable sshddos jail as well

# save the file and then restart the service
sudo service fail2ban restart

# be sure to restart fail2ban anytime the ferm config is updated because ferm overwrites the fail2ban iptable rules
```

Setup unattended upgrades
```
sudo vim /etc/apt/apt.conf.d/50unattended-upgrades
# confirm everything but the security upgrades are commented out
Unattended-Upgrade::Allowed-Origins {
        "${distro_id}:${distro_codename}-security";
//      "${distro_id}:${distro_codename}-updates";
//      "${distro_id}:${distro_codename}-proposed";
//      "${distro_id}:${distro_codename}-backports";
};

Unattended-Upgrade::Automatic-Reboot “false”;

# save the file if you made changes then enable the automated updates
sudo vim /etc/apt/apt.conf.d/10periodic
# make sure these lines appear in the file before saving
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
```

Download and Install Geocoder
```
su - dstk

git clone https://github.com/geocommons/geocoder.git
cd geocoder
make
sudo make install
```

Download and Install Dstk
```
cd ~
git clone https://github.com/paulyoder/dstk_street2coordinates
```

Copy the database file that was made earlier
```

```

Setup Nginx
```
todo
```

Create an Upstart process to run the puma webserver

```
su - deployer
sudo vim /etc/init/dstk.conf
# add the following lines to the file
description	"dstk server"

start on runlevel [2345]
stop on runlevel [!2345]

respawn
respawn limit 10 5

setuid dstk
setgid dstk

chdir /home/dstk/dstk

exec bundle exec puma -C config/puma.rb
```

Confirm it works!
