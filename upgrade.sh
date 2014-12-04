#!/bin/bash

wanted=$1

clone_path=/srv/software-factory
[ ! -d "$clone_path" ] && exit 1

# Check that we are able to jump on the request tag (SF version)
cd $clone_path && git checkout $wanted || {
    echo "$wanted version does not exist yet ! exit"
    exit 1
}

# Within the tag check we will be able to upgrade the current running SF version
source role_configrc
current_version=$(edeploy version | cut -d'-' -f2)
[ "$current_version" != "${PREVIOUS_SF_VER}" ] && {
    echo "The current version of Software Factory running here"
    echo "cannot be updated. From $wanted we are only able to"
    echo "update from ${PREVIOUS_SF_VER} to ${SF_VER}"
    exit 1
}

# get the domain from sfconfig.yaml
DOMAIN=$(egrep "^domain:" /etc/puppet/hiera/sf/sfconfig.yaml | sed 's/domain://' | tr -d ' ')

# Start the upgrade by jumping in the cloned version and running
# the ansible playbook.
cd ${clone_path}/upgrade/${PREVIOUS_SF_VER}/${SF_VER}/
cp group_vars/all.tmpl group_vars/all
sed -i "s/FROM/${PREVIOUS_SF_VER}/" group_vars/all
sed -i "s/TO/${SF_VER}/" group_vars/all
sed -i "s/DOMAIN/${DOMAIN}/" group_vars/all
sed -i "s/CLONE_PATH/${clone_path}/" group_vars/all
ansible-playbook -i hosts site.yml
cd -
