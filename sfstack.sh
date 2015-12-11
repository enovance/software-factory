#!/bin/bash
# Small utility to deploy SF like OpenStack devstack

set -e

echo "[+] Install dependencies"
sudo yum update -y
sudo yum install -y libvirt-daemon-lxc libvirt git vim-enhanced tmux curl python-devel wget python-pip python-virtualenv mariadb-devel gcc libffi-devel openldap-devel openssl-devel python-sphinx
sudo pip install ansible
sudo systemctl restart libvirtd

echo "[+] Fetch image"
./fetch_image.sh

echo "[+] Make sure no instance is already running"
(cd deploy/lxc; sudo ./deploy.py stop)

echo "[+] Start LXC container"
(cd deploy/lxc; sudo ./deploy.py init)

echo "[+] Wait for ssh"
sleep 5
touch ~/.ssh/known_hosts
sed -i '/.*192\.168\.135\.101.*/d' ~/.ssh/known_hosts
ssh-keyscan 192.168.135.101 >> ~/.ssh/known_hosts

echo "[+] Auto configure"
ssh root@192.168.135.101 sfconfig.sh > /dev/null

echo "[+] Run serverspec"
ssh root@192.168.135.101 "cd /etc/serverspec; rake spec"

echo "[+] SF is ready to be used:"
echo "echo PUBLIC_IP sftests.com | sudo tee -a /etc/hosts"
echo "firefox https://sftests.com"
