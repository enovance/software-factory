#!/bin/bash

KOJI_JOBS_VERSION="master"

. base.sh

# Fetch the koji-jobs library
git clone https://softwarefactory-project.io/r/koji-jobs
(
    cd koji-jobs
    git checkout $KOJI_JOBS_VERSION
    . image/koji-client-base.sh
    sudo ./install.sh
)
sudo sync
