#!/bin/sh

set -ex

export PATH=/sbin:/bin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

# Change cwd to .
cd $(dirname $BASH_SOURCE[0])

unset http_proxy
unset https_proxy

if [ ! -n "${OS_AUTH_URL}" ] || [ ! -n "${OS_PASSWORD}" ]; then
    echo "You must source openrc first"
    exit -1
fi

# Fix OS_AUTH_URL to br-ex ip
export OS_AUTH_URL=http://$(ip addr show dev br-ex | grep 'inet ' | sed 's/ *inet \([^\/]*\)\/.*/\1/'):5000

# Fetch network name
export OS_FLOATINGPOOL_NAME=$(nova floating-ip-pool-list | tail -n 2 | head -n 1 | awk '{ print $2 }')

exec ansible-playbook -i inventory main.yaml
