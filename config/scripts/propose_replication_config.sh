#!/bin/bash

set -x
set -e

# Only execute that if the config repository does not embed replication.config yet
[ ! -f /root/config/gerrit/replication.config ] && {
    mkdir /root/config/gerrit || true
    cp /home/gerrit/site_path/etc/replication.config /root/config/gerrit/
    cd /root/config
    if [ -n "$(git ls-files -o -m --exclude-standard)" ]; then
        git add -A
        git commit -m "Add gerrit/replication.config in the config repository"
        git review -i
    fi
}
