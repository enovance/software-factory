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

LOCK="/var/run/sf-build_roles.lock"
if [ -f ${LOCK} ]; then
    echo "Lock file present: ${LOCK}"
    killall softwarefactory.install
fi
sudo touch ${LOCK}
trap "sudo rm -f ${LOCK}" EXIT

set -e
[ -n "$DEBUG" ] && set -x

. ./role_configrc

CURRENT=`pwd`
SF_ROLES=$CURRENT/edeploy/

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

function build_role {
    ROLE_NAME="$1"
    ROLE_MD5="$2"
    ROLE_FILE="${INST}/${ROLE_NAME}-${SF_VER}"
    UPSTREAM_FILE="${UPSTREAM}/${ROLE_NAME}-${SF_VER}"

    echo "${ROLE_NAME} local hash is ${ROLE_MD5}"

    if [ ! -f "${ROLE_FILE}.md5" ] || [ "$(cat ${ROLE_FILE}.md5)" != "${ROLE_MD5}" ]; then
        echo "The local cache for ${ROLE_NAME} md5 ($(cat ${ROLE_FILE}.md5)) is different to what we computed from your git branch state (${ROLE_MD5})."
        [ ! -d "${INST}/${ROLE_NAME}_cache" ] && sudo mkdir -p "${INST}/${ROLE_NAME}_cache"
        [ -z "$SKIP_BUILD" ] && {
            echo "Rebuilding cache now..."
            cd $SF_ROLES
            STEP=1 SDIR=/var/lib/sf/git/edeploy sudo -E ./softwarefactory.install "${INST}/${ROLE_NAME}_cache" centos ${SF_VER}
            cd -
        } || {
            echo "Skip rebuilding cache (forced)."
            return
        }
    fi
}

function finalize_role {
    ROLE_NAME="$1"
    ROLE_FILE="${INST}/${ROLE_NAME}-${SF_VER}"

    # Make sure role tree is not mounted
    grep -q "${SF_VER}\/${ROLE_NAME}_cache\/proc" /proc/mounts && {
        while true; do
            sudo umount ${INST}/${ROLE_NAME}_cache/proc || break
        done
    }

    [ ! -d "${INST}/${ROLE_NAME}" ] && sudo mkdir -p "${INST}/${ROLE_NAME}"
    sudo rsync -a --delete "${INST}/${ROLE_NAME}_cache/" "${INST}/${ROLE_NAME}/"

    TAGGED_RELEASE=${TAGGED_RELEASE} PYSFLIB_PINNED_VERSION=${PYSFLIB_PINNED_VERSION} \
    MANAGESF_PINNED_VERSION=${MANAGESF_PINNED_VERSION} CAUTH_PINNED_VERSION=${CAUTH_PINNED_VERSION} \
    sudo -E ./edeploy/fetch_subprojects.sh

    cd $SF_ROLES
    STEP=2 DOCDIR=$DOCDIR GERRITHOOKS=$GERRITHOOKS PYSFLIB_CLONED_PATH=$PYSFLIB_CLONED_PATH \
    CAUTH_CLONED_PATH=$CAUTH_CLONED_PATH MANAGESF_CLONED_PATH=$MANAGESF_CLONED_PATH \
    SDIR=/var/lib/sf/git/edeploy \
    sudo -E ./softwarefactory.install ${INST}/${ROLE_NAME} centos ${SF_VER}
    cd -

    echo ${ROLE_MD5} | sudo tee ${ROLE_FILE}.md5
}

prepare_buildenv
fetch_edeploy
build_role "softwarefactory" $(find ${BASE_DEPS} -type f -not -path "*/.git/*" | sort | xargs cat | md5sum | awk '{ print $1}')
finalize_role "softwarefactory"
if [ -n "$VIRT" ]; then
    echo "Upstream ${ROLE_NAME} is NOT similar ! I rebuild the qcow2 image."
    build_img ${ROLE_FILE} ${INST}/${ROLE_NAME} $IMG_CFG
fi
