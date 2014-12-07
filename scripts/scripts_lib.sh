#!/bin/bash

# Copyright (C) 2014 eNovance SAS <licensing@enovance.com>
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

set -e
[ -n "$DEBUG" ] && set -x

SF_ROOT=$(dirname $(readlink $0 || echo $0))/../

source ${SF_ROOT}/role_configrc

function lock {
    # Make script exit if already running
    LOCK="/var/run/$(basename $0 .sh).lock"
    if [ -f ${LOCK} ]; then
        echo "Lock file present: ${LOCK}"
        exit -1
    fi
    sudo touch ${LOCK}
    trap "sudo rm -f ${LOCK}" 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15
}

function die {
    # Print $1 and exit
    echo "[ERROR]: $1"
    exit -1
}

function prepare_buildenv {
    # Create all required directory with permissions
    if [ ! -d $WORKSPACE ]; then
        sudo mkdir -m 0770 $WORKSPACE
        sudo chown ${USER}:root $WORKSPACE
    fi

    [ ! -d "$BUILD_DIR" ] && sudo mkdir -p $BUILD_DIR
    [ ! -d "$UPSTREAM" ] && sudo mkdir -p $UPSTREAM
    [ ! -d "$CLONES_DIR" ] && sudo mkdir -p $CLONES_DIR
    sudo chown -R ${USER} ${CLONES_DIR}
}

function fetch_edeploy {
    # Install edeploy dependency
    if [ ! -d "${EDEPLOY}" ]; then
        git clone $EDEPLOY_PROJECT ${EDEPLOY}
    fi
    if [ ! -d "${EDEPLOY_ROLES}" ]; then
        git clone $EDEPLOY_ROLES_PROJECT ${EDEPLOY_ROLES}
    fi
    # Make sure the correct tag is checked out
    (cd ${EDEPLOY};       git status | head -n 1 | sed 's/.* //' | grep -q $ED_TAG || git checkout -b $ED_TAG $ED_TAG || git checkout $ED_ROLES_TAG)
    (cd ${EDEPLOY_ROLES}; git status | head -n 1 | sed 's/.* //' | grep -q $ED_ROLES_TAG || git checkout -b $ED_ROLES_TAG $ED_ROLES_TAG || git checkout $ED_ROLES_TAG)
    EDEPLOY_ROLES_REL=$(cd ${EDEPLOY_ROLES}; ${MAKE} version)
    echo
}
