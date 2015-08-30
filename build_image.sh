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

. ./role_configrc

function build_img {
    ROLE_FILE="${1}.img"
    ROLE_TREE_PATH="$2"
    CFG="$3"
    [ -f "$ROLE_FILE" ] && sudo rm -Rf $ROLE_FILE
    [ -f "${ROLE_FILE}.qcow2" ] && sudo rm -Rf "${ROLE_FILE}.qcow2"
    sudo $CREATE_IMG $ROLE_TREE_PATH $ROLE_FILE $CFG
    # Remove the raw image, only keep the qcow2 image
    sudo rm -f ${ROLE_FILE}
    sudo rm -f ${ROLE_FILE}.md5
    qcow2_md5=$(cat ${ROLE_FILE}.qcow2 | md5sum - | cut -d ' ' -f1)
    echo $qcow2_md5 | sudo tee ${ROLE_FILE}.qcow2.md5
}

function build {
    [ -d ${BUILD_DIR} ] || sudo mkdir -p ${BUILD_DIR}
    sudo ./image/softwarefactory.install ${BUILD_DIR}/software-factory-${SF_REL}
}

function install {
    # Install repository data
    sudo rsync -a --delete puppet/ ${BUILD_DIR}/software-factory-${SF_REL}/etc/puppetsf/
    sudo rsync -a --delete packstack-sf/ ${BUILD_DIR}/software-factory-${SF_REL}/root/packstack-sf/
}

[ -z "$SKIP_BUILD" ] && build

install

echo "Success."
