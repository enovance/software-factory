#!/bin/bash

set -ex

[ -z "$1" ] && {
    echo "Please provide old name as arg 1"
    exit 1
}
[ -z "$2" ] && {
    echo "Please provide new name as arg 2"
    exit 1
}

ssh -i /root/sf-bootstrap-data/ssh_keys/gerrit_service_rsa -p 29418 admin@managesf gerrit rename-group "$1-ptl" "$2-ptl"
ssh -i /root/sf-bootstrap-data/ssh_keys/gerrit_service_rsa -p 29418 admin@managesf gerrit rename-group "$1-core" "$2-core"
