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

. ./role_configrc
[ -n "$DEBUG" ] && set -x

[ -z "$1" ] || SF_VER=$1

function die {
    echo "[ERROR]: $1"
    exit -1
}

function sync_prebuilt {
    echo "Fetch prebuilt SF roles ..."
    if [ -f "${UPSTREAM}/${IMG}.edeploy" ]; then
        echo "${UPSTREAM}/${IMG}.edeploy already exists..."
        return
    fi
    TMP_FILE=$(mktemp /tmp/swift_hash-XXXX)
    curl -o ${TMP_FILE} ${SWIFT_SF_URL}/${IMG}.hash
    # Swift does not return 404 but 'Not Found'
    grep -q 'Not Found' $TMP_FILE && die "$IMG does not exist upstream"
    if [ -f "${UPSTREAM}/${IMG}.hash" ]; then
        # Check if already synced
        diff ${TMP_FILE} ${UPSTREAM}/${IMG}.hash && return
    fi
    echo "Fetching ${SWIFT_SF_URL}/${IMG}.edeploy"
    sudo curl -o ${UPSTREAM}/${IMG}.edeploy ${SWIFT_SF_URL}/${IMG}.edeploy
    sudo curl -o ${UPSTREAM}/${IMG}.pip ${SWIFT_SF_URL}/${IMG}.pip || true
    sudo curl -o ${UPSTREAM}/${IMG}.rpm ${SWIFT_SF_URL}/${IMG}.rpm || true
    sudo curl -o ${UPSTREAM}/${IMG}.md5sum ${SWIFT_SF_URL}/${IMG}.md5sum || true
    sudo mv ${TMP_FILE} ${UPSTREAM}/${IMG}.hash
    (cd ${UPSTREAM}; exec md5sum -c ./${IMG}.md5sum) || exit -1
}

function sync_and_deflate {
    DST=$1
    IMG=$2
    sync_prebuilt
    SRC=${UPSTREAM}/$2.edeploy
    if [ -d ${DST} ]; then
        sudo rm -Rf ${DST}
    fi
    sudo mkdir -p ${DST}
    echo "[+] Extract image ${SRC} to ${DST}"
    sudo tar -xzf ${SRC} -C "${DST}"
    echo "[+] Copy metadata"
    sudo cp ${UPSTREAM}/${IMG}.hash ${DST}/../${IMG}.hash
    sudo cp ${UPSTREAM}/${IMG}.pip ${DST}/../${IMG}.pip
    sudo cp ${UPSTREAM}/${IMG}.rpm ${DST}/../${IMG}.rpm
    sudo cp ${UPSTREAM}/${IMG}.md5sum ${DST}/../${IMG}.md5sum
}

prepare_buildenv
if [ ! -z "$FETCH_CACHE" ]; then
    sync_and_deflate ${CACHE_PATH} "sf-centos7"
else
    sync_and_deflate ${IMAGE_PATH} "softwarefactory-${SF_VER}"
fi
