#!/bin/sh
ACTION=${1:-sf_configrepo_update}
case $ACTION in
    sf_configrepo_update)
        exec ansible-playbook /etc/ansible/sf_configrepo_update.yml
        ;;
    sf_mirror_update)
        exec ansible-playbook /etc/ansible/roles/sf-mirror/files/update_playbook.yml
        ;;
    *)
        echo "NotImplemented"
        exit -1
esac
