#!/bin/bash

set -xe

sudo yum update -y > /dev/null

# Base requirements
sudo yum install -y epel-release > /dev/null
sudo yum install -y python-pip git wget curl patch iproute > /dev/null
sudo pip install --upgrade 'pip<8'
sudo pip install tox

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
sudo yum install -y java

# Install zuul_swift_upload and zuul-cloner
# TODO: replace this section by zuul package
sudo yum install -y python-requests gcc python-devel
sudo pip install zuul glob2 python-magic
sudo curl -o /usr/local/bin/zuul_swift_upload.py \
    https://raw.githubusercontent.com/openstack-infra/project-config/master/jenkins/scripts/zuul_swift_upload.py
sudo chmod +x /usr/local/bin/zuul_swift_upload.py

# Fetch some tooling for the slave node
git clone http://softwarefactory-project.io/r/software-factory --depth 1
(
    cp software-factory/tools/slaves/wait_for_other_jobs.py /usr/local/bin/wait_for_other_jobs.py
    chmod +x /usr/local/bin/wait_for_other_jobs.py
)
rm -Rf software-factory

# sync FS, otherwise there are 0-byte sized files from the yum/pip installations
sudo sync
sudo sync

sudo cat /home/jenkins/.ssh/authorized_keys

echo "Base setup done."
