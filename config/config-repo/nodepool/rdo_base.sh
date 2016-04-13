#!/bin/bash

[ -n "${RDO_RELEASE}" ] || RDO_RELEASE=https://repos.fedorapeople.org/repos/openstack/openstack-mitaka/rdo-release-mitaka-3.noarch.rpm

sudo yum install -y ${RDO_RELEASE} > /dev/null
sudo yum update -y > /dev/null

echo "Make sure pycrypto wasn't installed by pip, otherwise it will failed after when trying to install python-crypto"
sudo pip uninstall -y pycrypto > /dev/null || true
# Error message when trying yum install python-cyrpto:
# Error unpacking rpm package python2-crypto-2.6.1-9.el7.x86_64
# error: unpacking of archive failed on file /usr/lib64/python2.7/site-packages/pycrypto-2.6.1-py2.7.egg-info: cpio: rename
# error: python2-crypto-2.6.1-9.el7.x86_64: install failed

# To re-generate, after packstack install do:
# sudo awk '/Installed:/ { print $5 }' /var/log/yum.log | xargs yum info | awk '/Name        :/ { print $3 }' | tee req.txt
echo "Install rdo requirements..."
time sudo yum install -y $(cat rdo_requirements.txt) > /dev/null

sudo cp -v /opt/nodepool-scripts/nested_cloud_prep.sh /usr/local/bin/

echo "RDO base setup done."

. swap_setup.sh

