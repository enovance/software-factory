#!/bin/bash
# SF environment requirements

which ansible &> /dev/null || {
    echo "Install test requirement..."
    sudo yum install -y epel-release
    sudo yum install -y python-pip libvirt-daemon-lxc libvirt && sudo systemctl restart libvirtd
    sudo pip install --upgrade pip
    sudo pip install -r test-requirements.txt
}
