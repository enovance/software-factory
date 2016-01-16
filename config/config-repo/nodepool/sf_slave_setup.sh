#!/bin/bash

. base.sh

# Create swap
sudo dd if=/dev/zero of=/srv/swap count=4000 bs=1M
sudo chmod 600 /srv/swap
sudo mkswap /srv/swap
grep swap /etc/fstab || echo "/srv/swap none swap sw 0 0" | sudo tee -a /etc/fstab

# Disable selinux
sudo sed -i 's/^.*SELINUX=.*$/SELINUX=disabled/' /etc/selinux/config

# Temporary DNS fix
echo "216.58.213.16 gerrit-releases.storage.googleapis.com" | sudo tee -a /etc/hosts
[ -d /var/lib/sf/artifacts ] || sudo mkdir -p /var/lib/sf/artifacts
sudo chown -R jenkins:jenkins /var/lib/sf/artifacts

# Install libvirt-lxc
sudo yum install -y libvirt-daemon-lxc libvirt
sudo systemctl restart libvirtd

# Fetch prebuilt image
git clone http://softwarefactory-project.io/r/software-factory --depth 1
(
    cd software-factory;
    bash rpm-requirements.sh
    bash rpm-test-requirements.sh
    SKIP_GPG=1 FETCH_CACHE=1 ./fetch_image.sh
    SKIP_GPG=1 ./fetch_image.sh
)

# sync FS, otherwise there are 0-byte sized files from the yum/pip installations
sudo sync
sudo sync

echo "Setup finished. Creating snapshot now, this will take a few minutes"
