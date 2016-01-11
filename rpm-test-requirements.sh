#!/bin/bash
# SF environment requirements

which ansible &> /dev/null || {
    echo "Install test requirement..."
    sudo yum install -y epel-release
    sudo yum install -y python-pip libvirt-daemon-lxc libvirt vim-enhanced tmux && sudo systemctl restart libvirtd
    sudo pip install --upgrade pip
    sudo pip install flake8 bash8 tox ansible
}
