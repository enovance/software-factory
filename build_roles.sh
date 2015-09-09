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

    # Make sure role tree is not mounted
    grep -q "${SF_VER}\/${ROLE_NAME}\/proc" /proc/mounts && {
        while true; do
            sudo umount ${INST}/${ROLE_NAME}/proc || break
        done
    }
    # Check if we can find roles built locally and that md5 is similar
    if [ -f "${ROLE_FILE}.md5" ] && [ "$(cat ${ROLE_FILE}.md5)" = "${ROLE_MD5}" ]; then
        echo "The locally built ${ROLE_NAME} md5 is similar to what we computed from your git branch state. Nothing to do"
        if [ -n "$VIRT" ] && [ ! -f "${ROLE_FILE}.img.qcow2" ]; then
            echo "The locally built qcow2 (${ROLE_FILE}.img.qcow2) is not available ! so built it."
            build_img ${ROLE_FILE} ${INST}/${ROLE_NAME} $IMG_CFG
        fi
        return
    fi
    # Check upstream role MD5 to know if upstream role can be re-used
    # TODO how to include checking external libs in the build check ?
    # Provide SKIP_UPSTREAM=1 to avoid checking the upstream pre-built role
    if [ -f "${UPSTREAM_FILE}.md5" ] && [ "$(cat ${UPSTREAM_FILE}.md5)" == "${ROLE_MD5}" ] && [ -z "$SKIP_UPSTREAM" ]; then
        echo "Upstream ${ROLE_NAME} md5 is similar to what we computed from your git branch state, I will use the upstream role."
        sudo rm -Rf ${INST}/${ROLE_NAME}
        sudo mkdir ${INST}/${ROLE_NAME}
        echo "Unarchive ..."
        sudo tar -xzf ${UPSTREAM_FILE}.edeploy -C "${INST}/${ROLE_NAME}"
        echo ${ROLE_MD5} | sudo tee ${ROLE_FILE}.md5
        if [ -n "$VIRT" ]; then
            echo "Copy prebuilt qcow2 image ..."
            if [ -f ${UPSTREAM_FILE}.img.qcow2 ]; then
                sudo cp ${UPSTREAM_FILE}.img.qcow2 ${INST}/
                sudo cp ${UPSTREAM_FILE}.img.qcow2.md5 ${INST}/
            else
                # Should not be the case !
                echo "Prebuilt qcow2 image ${UPSTREAM_FILE}.img.qcow2 is not available upstream ! so build it."
                build_img ${ROLE_FILE} ${INST}/${ROLE_NAME} $IMG_CFG
            fi
        fi
    else
        if [ ! -f "${ROLE_FILE}.md5" ] || [ "$(cat ${ROLE_FILE}.md5)" != "${ROLE_MD5}" ]; then
            echo "The locally built ${ROLE_NAME} md5 ($(cat ${ROLE_FILE}.md5)) is different to what we computed from your git branch state (${ROLE_MD5})."
            echo "Building role now..."
            TOP=/var/lib/debootstrap SDIR=/var/lib/sf/git/edeploy sudo -E ./softwarefactory.install ${INST}/${ROLE_NAME} centos ${SF_VER}
            echo ${ROLE_MD5} | sudo tee ${ROLE_FILE}.md5
            if [ -n "$VIRT" ]; then
                echo "Upstream ${ROLE_NAME} is NOT similar ! I rebuild the qcow2 image."
                build_img ${ROLE_FILE} ${INST}/${ROLE_NAME} $IMG_CFG
            fi
        fi
    fi
}

function do_chroot {
    croot=$1
    shift
    sudo chroot $croot "${@}"
}
function install_sf {
    set -e
    dir=${INST}/${ROLE_NAME}
    # Install puppet files for SF
    do_chroot ${dir} mkdir -p /etc/puppet/environments/sf
    do_chroot ${dir} mkdir -p /etc/puppet/hiera/sf
    sudo cp -Rv ./puppet/manifests ${dir}/etc/puppet/environments/sf
    sudo cp -Rv ./puppet/modules ${dir}/etc/puppet/environments/sf
    sudo cp -Rv ./puppet/hiera/* ${dir}/etc/puppet/hiera/sf
    sudo cp -Rv ./puppet/hiera.yaml ${dir}/etc/puppet/
    # Install the bootstrap scripts
    sudo mkdir ${dir}/root/puppet-bootstrapper
    sudo cp -Rv ./tests ${dir}/root/puppet-bootstrapper/
    sudo cp -Rv ./tools ${dir}/root/puppet-bootstrapper/
    sudo cp -Rv ./serverspec ${dir}/root/puppet-bootstrapper/
    sudo cp -Rv ./bootstraps/*.sh ${dir}/root/puppet-bootstrapper/
    sudo cp -Rv ./bootstraps/sfcreds.yaml ${dir}/root/puppet-bootstrapper/

    # Install pysflib, managesf, cauth
    # Cauth server. cauth has been checkouted before on the build node in /tmp
    [ ! -d "${dir}/var/www/cauth" ] && sudo mkdir ${dir}/var/www/cauth
    sudo cp -Rv ${CAUTH_CLONED_PATH}/* ${dir}/var/www/cauth/
    # override pysflib version from requirements
    do_chroot ${dir} sed -i '/pysflib/d' /var/www/cauth/requirements.txt
    do_chroot ${dir} bash -c "cd /var/www/cauth && SWIG_FEATURES='-cpperraswarn -includeall -I/usr/include/openssl' pip install -r requirements.txt"
    do_chroot ${dir} bash -c "cd /var/www/cauth && python setup.py install"

    sudo mkdir -p ${dir}/root/puppet-bootstrapper/tools/pysflib
    sudo cp -Rv ${PYSFLIB_CLONED_PATH}/* ${dir}/root/puppet-bootstrapper/tools/pysflib/
    do_chroot ${dir} bash -c "cd /root/puppet-bootstrapper/tools/pysflib; pip install -r requirements.txt"
    do_chroot ${dir} bash -c "cd /root/puppet-bootstrapper/tools/pysflib; python setup.py install"

    # install sfmanager. managesf has been checkouted before on the build node in /tmp
    sudo mkdir -p ${dir}/root/puppet-bootstrapper/tools/managesf
    sudo cp -Rv ${MANAGESF_CLONED_PATH}/* ${dir}/root/puppet-bootstrapper/tools/managesf/
    # override pysflib version from requirements
    do_chroot ${dir} sed -i '/pysflib/d' /root/puppet-bootstrapper/tools/managesf/requirements.txt
    do_chroot ${dir} bash -c "cd /root/puppet-bootstrapper/tools/managesf; pip install -r requirements.txt"
    do_chroot ${dir} bash -c "cd /root/puppet-bootstrapper/tools/managesf; python setup.py install"

    # install requirements for functional tests
    do_chroot ${dir} bash -c "cd /root/puppet-bootstrapper/tests; pip install -r requirements.txt"
}

function build_roles {
    [ ! -d "$BUILD_DIR/install/${DVER}-${SF_REL}" ] && sudo mkdir -p $BUILD_DIR/install/${DVER}-${SF_REL}

    cd $SF_ROLES
    build_role "softwarefactory" $(cat third_party_tools)
    cd ..
    IE=$?
}

prepare_buildenv
fetch_edeploy
TAGGED_RELEASE=${TAGGED_RELEASE} PYSFLIB_PINNED_VERSION=${PYSFLIB_PINNED_VERSION} MANAGESF_PINNED_VERSION=${MANAGESF_PINNED_VERSION} CAUTH_PINNED_VERSION=${CAUTH_PINNED_VERSION} ./edeploy/fetch_subprojects.sh
[ -z "${SKIP_BUILD}" ] && build_roles
install_sf
exit $IE
