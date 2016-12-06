#!/bin/bash

SHA="master"

. base.sh

# Fetch the koji-jobs library
git clone http://softwarefactory-project.io/r/koji-jobs
(
    cd koji-jobs
    git checkout $SHA
    mkdir /var/lib/koji-jobs/
    cp -av koji-jobs/* /var/lib/koji-jobs/
    . image/koji-client-base.sh
)
sudo sync
