#!/bin/bash

# Create swap
if [ ! -f /srv/swap ]; then
    sudo dd if=/dev/zero of=/srv/swap count=4000 bs=1M
    sudo chmod 600 /srv/swap
    sudo mkswap /srv/swap
    grep swap /etc/fstab || echo "/srv/swap none swap sw 0 0" | sudo tee -a /etc/fstab
    echo "Swap created."
fi
