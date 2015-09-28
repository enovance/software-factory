#!/bin/bash
# Small utility to deploy SF like OpenStack devstack

set -e

echo "[+] Install dependencies"
sudo yum update -y
sudo yum install -y ...
sudo systemctl restart libvirtd

echo "[+] Fetch image"
./fetch_image.sh

echo "[+] Start LXC container"
(cd deploy/lxc; sudo ./deploy.py init)

echo "[+] Auto configure"
ssh root@192.168.135.101 "cd bootstraps; ./bootstraps.sh"

echo "[+] Run serverspec"
ssh root@192.168.135.101 "cd serverspec; rake spec"

echo "[+] SF is ready to be used:"
echo "echo PUBLIC_IP tests.dom | sudo tee -a /etc/hosts"
echo "firefox https://tests.dom"
