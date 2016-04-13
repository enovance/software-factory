#!/bin/bash

. base.sh

RDO_RELEASE=https://repos.fedorapeople.org/repos/openstack/openstack-liberty/rdo-release-liberty-2.noarch.rpm

. rdo_base.sh

# Disable selinux
sudo sed -i 's/^.*SELINUX=.*$/SELINUX=disabled/' /etc/selinux/config

# sync FS, otherwise there are 0-byte sized files from the yum/pip installations
sudo sync
sudo sync

echo "SUCCESS: rdo-liberty-centos-7 done."
