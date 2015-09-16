#!/bin/bash

. base.sh

# This should be removed after we fix functestlib.sh and how
# we manage to store artifacts
sudo useradd www-data

sudo yum install -y epel-release

sudo yum install -y git python-augeas bridge-utils curl lxc wget swig python-devel python-pip graphviz python-yaml
sudo pip install flake8 bash8
sudo pip install -U tox==1.6.1 virtualenv==1.10.1 Sphinx oslosphinx

sudo dd if=/dev/zero of=/srv/swap count=4000 bs=1M
sudo chmod 600 /srv/swap
sudo mkswap /srv/swap
grep swap /etc/fstab || echo "/srv/swap none swap sw 0 0" | sudo tee -a /etc/fstab

sudo sed -i 's/^.*SELINUX=.*$/SELINUX=disabled/' /etc/selinux/config

sudo git clone https://github.com/enovance/edeploy-lxc.git /srv/edeploy-lxc

sudo mkdir -p /var/lib/sf
sudo mkdir -p /var/lib/sf/artifacts/logs
sudo chown -R jenkins:jenkins /var/lib/sf/

# sync FS, otherwise there are 0-byte sized files from the yum/pip installations
sudo sync

echo "Setup finished. Creating snapshot now, this will take a few minutes"
