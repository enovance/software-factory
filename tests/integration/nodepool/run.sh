#!/bin/sh

set -ex

if [ ! -n "${OS_AUTH_URL}" ] || [ ! -n "${OS_PASSWORD}" ]; then
    echo "You must source openrc first"
    exit -1
fi

# Temp fix for auth url
#OS_AUTH_URL=$(openstack catalog show identity | grep 'publicURL' | awk '{ print $4 }')
OS_AUTH_URL=http://192.168.0.50:5000/v2.0

# Fetch network name
export OS_FLOATINGPOOL_NAME=$(nova floating-ip-pool-list | tail -n 2 | head -n 1 | awk '{ print $2 }')

ansible-playbook -i inventory main.yaml
