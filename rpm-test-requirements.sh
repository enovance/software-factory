#!/bin/bash
# SF environment requirements
sudo yum install -y libvirt-daemon-lxc libvirt vim-enhanced tmux ansible && sudo systemctl restart libvirtd
