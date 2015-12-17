#!/bin/bash

#Will be 1 if installed, or 0 if not
ANSIBLE_INSTALLED=`which ansible-playbook | wc -l`

if [ "$ANSIBLE_INSTALLED" == "1" ]; then

  echo
  #echo "Skipping ansible install since it's already installed."

else

  echo "Ansible doesn't appear to be installed. Installing now..."

  #first, update our cache:
  sudo apt-get update

  #Now, install python-software-properties so we have "add-apt-repository" available
  sudo apt-get -y install python-software-properties

  #Now add the ansible repository:
  sudo add-apt-repository ppa:rquillo/ansible

  #Now we run this again so that we get the very latest version of ansible
  sudo apt-get update

  #finally, install ansible
  sudo apt-get -y install ansible
fi

# We set PYTHONUNBUFFERED to true so that ansible-playbook output appears "live" when Vagrant provisioning
# We use ANSIBLE_FORCE_COLOR because Ansible thinks it's being run from a non-interactive shell when run by Vagrant, so it turns off colors. Vagrant understands them though, so we force colors
cd "${BASH_SOURCE%/*}"
sudo PYTHONUNBUFFERED=1 ANSIBLE_FORCE_COLOR=1 ansible-playbook ./playbook.yml