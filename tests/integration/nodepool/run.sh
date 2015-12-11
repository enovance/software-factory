#!/bin/sh

set -ex

#AUTH_URL=$(openstack catalog show identity | grep 'publicURL' | awk '{ print $4 }')
AUTH_URL=http://192.168.0.50:5000/v2.0

cat group_vars/all.tmpl | sed -e "s#AUTH_URL#${AUTH_URL}#" > group_vars/all

ansible-playbook -i inventory main.yaml
