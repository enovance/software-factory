#!/bin/sh

if [ "$1" == "stop" ]; then
    for instance in $(sudo lxc-ls); do
        sudo lxc-stop --kill --name ${instance}
    done
fi

exec sudo python start.py $*
