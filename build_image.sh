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
if [ -f ${LOCK} ]; then
    echo "Lock file present: ${LOCK}"
    killall softwarefactory.install
    killall sf.install
fi
sudo touch ${LOCK}
trap "sudo rm -f ${LOCK}" EXIT

. ./role_configrc
[ -n "$DEBUG" ] && set -x

IMAGE_OUTPUT=/dev/stdout
if [ ! -z "${1}" ]; then
    ARTIFACTS_DIR=${1}/edeploy
    sudo mkdir -p ${ARTIFACTS_DIR}
    USER=$(whoami)
    sudo chown -R $USER:$USER ${ARTIFACTS_DIR}
fi

function build_qcow {
    IMAGE_FILE="${INST}/softwarefactory-${SF_VER}.img"
    IMAGE_TREE_PATH="${INST}/softwarefactory"
    [ -f "$IMAGE_FILE" ] && sudo rm -Rf $IMAGE_FILE
    [ -f "${IMAGE_FILE}.qcow2" ] && sudo rm -Rf "${IMAGE_FILE}.qcow2"
    sudo ./image/create-image.sh $IMAGE_TREE_PATH $IMAGE_FILE ./image/params.virt
    # Remove the raw image, only keep the qcow2 image
    sudo rm -f ${IMAGE_FILE} ${IMAGE_FILE}.md5
    qcow2_md5=$(cat ${IMAGE_FILE}.qcow2 | md5sum - | cut -d ' ' -f1)
    echo $qcow2_md5 | sudo tee ${IMAGE_FILE}.qcow2.md5
}

function build_cache {
    [ -z "${SKIP_BUILD}" ] || return
    CACHE_HASH="SF: $(git log --format=oneline -n 1 $CACHE_DEPS)"
    LOCAL_HASH="$(cat ${CACHE_PATH}.hash 2> /dev/null)"

    if [ "${LOCAL_HASH}" != "${CACHE_HASH}" ]; then
        echo "(STEP1) The local cache needs update (want: [${CACHE_HASH}], was: [${LOCAL_HASH}])"
        sudo rm -Rf ${CACHE_PATH}*
        sudo mkdir -p ${CACHE_PATH}
        if [ ! -z "${ARTIFACTS_DIR}" ]; then
            IMAGE_OUTPUT=${ARTIFACTS_DIR}/step1_cache_build.log
        fi
        (
            set -e
            cd image
            STEP=1 SDIR=/var/lib/sf/git/edeploy sudo -E ./softwarefactory.install ${CACHE_PATH} ${SF_VER} &> ${IMAGE_OUTPUT}
            sudo chroot ${CACHE_PATH} pip freeze | sort | sudo tee ${CACHE_PATH}.pip &> /dev/null
            sudo chroot ${CACHE_PATH} rpm -qa | sort | sudo tee ${CACHE_PATH}.rpm &> /dev/null
            echo ${CACHE_HASH} | sudo tee ${CACHE_PATH}.hash > /dev/null
        )
        if [ "$?" != "0" ]; then
            echo "(STEP1) FAILED"; sudo rm -Rf ${CACHE_PATH}.hash; exit 1;
        fi
    else
        echo "(STEP1) Already built, remove ${CACHE_PATH}.hash to force rebuild..."
    fi
    echo "(STEP1) SUCCESS: ${CACHE_HASH}"
}

function build_image {
    IMAGE_HASH="SF: $(git log --format=oneline -n 1) || CAUTH: $(cd ${CAUTH_CLONED_PATH}; git log --format=oneline -n 1) || PYSFLIB: $(cd ${PYSFLIB_CLONED_PATH}; git log --format=oneline -n 1) || MANAGESF: $(cd ${MANAGESF_CLONED_PATH}; git log --format=oneline -n 1)"
    LOCAL_HASH=$(cat ${IMAGE_PATH}-${SF_VER}.hash 2> /dev/null)

    if [ "${LOCAL_HASH}" != "${IMAGE_HASH}" ]; then
        echo "(STEP2) The local image needs update (want: [${IMAGE_HASH}], was: [${LOCAL_HASH}])"
        sudo rm -Rf ${IMAGE_PATH}*
        sudo mkdir -p ${IMAGE_PATH}

        # Make sure image tree is not mounted
        grep -q "${CACHE_PATH}\/proc" /proc/mounts && {
            while true; do
                sudo umount ${CACHE_PATH}/proc || break
            done
        }

        if [ ! -z "${ARTIFACTS_DIR}" ]; then
            IMAGE_OUTPUT=${ARTIFACTS_DIR}/step2_build.log
        fi

        # Copy the cache
        sudo rsync -a --delete "${CACHE_PATH}/" "${IMAGE_PATH}/"

        (
            set -e
            cd image
            STEP=2 DOCDIR=$DOCDIR GERRITHOOKS=$GERRITHOOKS PYSFLIB_CLONED_PATH=$PYSFLIB_CLONED_PATH \
            CAUTH_CLONED_PATH=$CAUTH_CLONED_PATH MANAGESF_CLONED_PATH=$MANAGESF_CLONED_PATH \
            SDIR=/var/lib/sf/git/edeploy \
            sudo -E ./softwarefactory.install ${IMAGE_PATH} ${SF_VER} &> ${IMAGE_OUTPUT}

            sudo chroot ${IMAGE_PATH} pip freeze | sort | sudo tee ${IMAGE_PATH}-${SF_VER}.pip &> /dev/null
            sudo chroot ${IMAGE_PATH} rpm -qa | sort | sudo tee ${IMAGE_PATH}-${SF_VER}.rpm &> /dev/null
            echo ${IMAGE_HASH} | sudo tee ${IMAGE_PATH}-${SF_VER}.hash > /dev/null
        )
        if [ "$?" != "0" ]; then
            echo "(STEP2) FAILED"; sudo rm -Rf ${IMAGE_PATH}-${SF_VER}.hash; exit 1;
        fi
    else
        echo "(STEP2) Already built, remove ${IMAGE_PATH}-${SF_VER}.hash to force rebuild..."
    fi
    echo "(STEP2) SUCCESS: ${IMAGE_HASH}"
}

./image/fetch_subprojects.sh
prepare_buildenv
build_cache
build_image
if [ -n "$VIRT" ]; then
    build_qcow
fi
