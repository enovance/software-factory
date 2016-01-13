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

LOCK="/var/run/sf-build_image.lock"
function wait_for_lock {
    retry=0
    while [ $retry -lt 360 ]; do
        [ -f ${LOCK} ] || return
        echo "Lock file present: ${LOCK}"
        sleep 1;
        let retry=retry+1
    done
    exit -1
}

function put_lock {
    sudo touch ${LOCK}
    trap "sudo rm -f ${LOCK}" EXIT
}

wait_for_lock
put_lock

. ./role_configrc
[ -n "$DEBUG" ] && set -x

if [ ! -z "${1}" ]; then
    ARTIFACTS_DIR=${1}/image_build
    sudo mkdir -p ${ARTIFACTS_DIR}
    USER=$(whoami)
    sudo chown -R $USER:$USER ${ARTIFACTS_DIR}
fi

function build_qcow {
    IMAGE_FILE="${IMAGE_PATH}-${SF_VER}.img"
    [ -f "${IMAGE_FILE}" ] && sudo rm -Rf ${IMAGE_FILE}
    [ -f "${IMAGE_FILE}.qcow2" ] && sudo rm -Rf "${IMAGE_FILE}.qcow2"
    sudo ./image/create-image.sh ${IMAGE_PATH} ${IMAGE_FILE} ./image/params.virt
    # Remove the raw image, only keep the qcow2 image
    sudo rm -f ${IMAGE_FILE} ${IMAGE_FILE}.md5
}

function build_cache {
    [ -z "${SKIP_BUILD}" ] || return
    CACHE_HASH="SF: $(git log --format=oneline -n 1 $CACHE_DEPS)"
    LOCAL_HASH="$(head -n 1 ${CACHE_PATH}.description 2> /dev/null)"

    echo "(STEP1) ${CACHE_HASH}"
    if [ "${LOCAL_HASH}" == "${CACHE_HASH}" ]; then
        echo "(STEP1) Already built, remove ${CACHE_PATH}.description to force rebuild"
        return
    fi
    echo "(STEP1) The local cache needs update (was: [${LOCAL_HASH}])"
    sudo rm -Rf ${CACHE_PATH}*
    sudo mkdir -p ${CACHE_PATH}
    (
        set -e
        cd image
        STEP=1 sudo -E ./softwarefactory.install ${CACHE_PATH} ${SF_VER}
        echo ${CACHE_HASH} | sudo tee ${CACHE_PATH}.description > /dev/null
        ./get_image_versions_information.sh ${CACHE_PATH} | sudo tee -a ${CACHE_PATH}.description > /dev/null
    )
    if [ "$?" != "0" ]; then
        echo "(STEP1) FAILED"; sudo rm -Rf ${CACHE_PATH}.description; exit 1;
    fi
    echo "(STEP1) SUCCESS: ${CACHE_HASH}"
}

function build_image {
    # Image description is last commit of DEPS and the one that changed content of the image (bootstraps/ docs/ gerrit-hooks/ image/ puppet/)
    IMAGE_HASH="SF: $(git log --format=oneline -n 1 config/ docs/ image/ puppet/) || CAUTH: $(cd ${CAUTH_CLONED_PATH}; git log --format=oneline -n 1) || PYSFLIB: $(cd ${PYSFLIB_CLONED_PATH}; git log --format=oneline -n 1) || MANAGESF: $(cd ${MANAGESF_CLONED_PATH}; git log --format=oneline -n 1) || SFMANAGER: $(cd ${SFMANAGER_CLONED_PATH}; git log --format=oneline -n 1)"

    LOCAL_HASH=$(head -n 1 ${IMAGE_PATH}-${SF_VER}.description 2> /dev/null)

    echo "(STEP2) ${IMAGE_HASH}"
    if [ "${LOCAL_HASH}" == "${IMAGE_HASH}" ]; then
        echo "(STEP2) Already built, remove ${IMAGE_PATH}-${SF_VER}.description to force rebuild"
        return
    fi
    echo "(STEP2) The local image needs update (was: [${LOCAL_HASH}])"
    sudo rm -Rf ${IMAGE_PATH}*
    sudo mkdir -p ${IMAGE_PATH}

    # Make sure image tree is not mounted
    grep -q "${CACHE_PATH}\/proc" /proc/mounts && {
        while true; do
            sudo umount ${CACHE_PATH}/proc || break
        done
    }

    # Copy the cache
    sudo rsync -a --delete "${CACHE_PATH}/" "${IMAGE_PATH}/"

    (
        set -e
        cd image
        STEP=2 DOCDIR=$DOCDIR PYSFLIB_CLONED_PATH=$PYSFLIB_CLONED_PATH \
        CAUTH_CLONED_PATH=$CAUTH_CLONED_PATH MANAGESF_CLONED_PATH=$MANAGESF_CLONED_PATH \
        SFMANAGER_CLONED_PATH=$SFMANAGER_CLONED_PATH \
        sudo -E ./softwarefactory.install ${IMAGE_PATH} ${SF_VER}

        echo ${IMAGE_HASH} | sudo tee ${IMAGE_PATH}-${SF_VER}.description > /dev/null
        ./get_image_versions_information.sh ${IMAGE_PATH} | sudo tee -a ${IMAGE_PATH}-${SF_VER}.description > /dev/null
    )
    if [ "$?" != "0" ]; then
        echo "(STEP2) FAILED"; sudo rm -Rf ${IMAGE_PATH}-${SF_VER}.description; exit 1;
    fi
    echo "(STEP2) SUCCESS: ${IMAGE_HASH}"
}

prepare_buildenv
build_cache
# Make sure subproject are available
./image/fetch_subprojects.sh || exit 1
build_image
if [ -n "$BUILD_QCOW" ]; then
    echo "(STEP3) Building qcow, please wait..."
    build_qcow
fi
