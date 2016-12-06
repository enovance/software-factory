#!/bin/bash

SHA="master"

. base.sh

# Fetch the koji-jobs library
git clone http://softwarefactory-project.io/r/koji-jobs
(
    cd koji-jobs
    git checkout $SHA
    . image/koji-client-base.sh
    sudo ./install.sh
)
sudo sync
