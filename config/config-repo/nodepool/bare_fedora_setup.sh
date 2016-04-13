#!/bin/bash

set -ex

sudo dnf update -y

# Base requirements
sudo dnf install -y python-pip git wget curl patch iproute

# The jenkins user. Must be able to use sudo without password
sudo useradd -m jenkins
sudo gpasswd -a jenkins wheel
echo "jenkins ALL=(ALL) NOPASSWD:ALL" | sudo tee --append /etc/sudoers.d/90-cloud-init-users
echo "Defaults   !requiretty" | sudo tee --append /etc/sudoers.d/90-cloud-init-users

# SSH key for the Jenkins user
sudo mkdir /home/jenkins/.ssh
sudo cp /opt/nodepool-scripts/authorized_keys /home/jenkins/.ssh/authorized_keys
sudo ssh-keygen -N '' -f /home/jenkins/.ssh/id_rsa
sudo chown -R jenkins /home/jenkins/.ssh
sudo chmod 700 /home/jenkins/.ssh
sudo chmod 600 /home/jenkins/.ssh/authorized_keys
sudo restorecon -R -v /home/jenkins/.ssh/authorized_keys

# Nodepool will try to connect on the fresh node using the user
# defined as username in the provider.image section conf. Usually
# it is the clouduser. So fetch it and authorize the pub key
# for that user.
cloud_user=$(egrep " name:" /etc/cloud/cloud.cfg | awk '{print $2}')
cat /opt/nodepool-scripts/authorized_keys | sudo tee -a /home/$cloud_user/.ssh/authorized_keys

# Install java (required by Jenkins)
sudo dnf install -y java

# Install zuul_swift_upload and zuul-cloner
# TODO: replace this section by zuul package
sudo dnf install -y python-requests gcc python-devel python-cffi python-magic \
                    python-cryptography python-statsd python-glob2 python-paramiko \
                    PyYAML python-paste python-webob GitPython python-daemon \
                    python-extras python-voluptuous python-gear python-tox \
                    python-prettytable python-babel python-six
sudo pip install zuul 'paramiko<2'

# Copy slave tools
sudo cp -v /opt/nodepool-scripts/*.py /usr/local/bin/

# sync FS, otherwise there are 0-byte sized files from the dnf/pip installations
sudo sync
sudo sync

sudo cat /home/jenkins/.ssh/authorized_keys

echo "SUCCESS: bare-fedora-23 done."
