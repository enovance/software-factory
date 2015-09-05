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

function build {
    [ -d ${BUILD_DIR} ] || sudo mkdir -p ${BUILD_DIR}
    sudo ./image/softwarefactory.install ${BUILD_DIR}/software-factory-${SF_REL}
}

function install {
    # Install puppet files for SF
    do_chroot ${dir} mkdir -p /etc/puppet/environments/sf
    do_chroot ${dir} mkdir -p /etc/puppet/hiera/sf
    cp -Rv ./puppet/manifests ${dir}/etc/puppet/environments/sf
    cp -Rv ./puppet/modules ${dir}/etc/puppet/environments/sf
    cp -Rv ./puppet/hiera/* ${dir}/etc/puppet/hiera/sf
    cp -Rv ./puppet/hiera.yaml ${dir}/etc/puppet/

    # Install the bootstrap scripts
    mkdir ${dir}/root/puppet-bootstrapper
    cp -Rv ./tests ${dir}/root/puppet-bootstrapper/
    cp -Rv ./tools ${dir}/root/puppet-bootstrapper/
    cp -Rv ./serverspec ${dir}/root/puppet-bootstrapper/
    cp -Rv ./bootstraps/*.sh ${dir}/root/puppet-bootstrapper/
    cp -Rv ./bootstraps/sfcreds.yaml ${dir}/root/puppet-bootstrapper/
}

function deflate_upstream {
    TARGET_DIR="${BUILD_DIR}/software-factory-${SF_REL}"
    [ -d "${TARGET_DIR}" ] || sudo mkdir -p "${TARGET_DIR}"
    curl -s -o - "${SWIFT_SF_URL}/software-factory-${SF_REL}" | tar -xzpf - -C ${TARGET_DIR}
}

echo "[+] Check upstream"
UPSTREAM_MD5=$(curl -s -o - "${SWIFT_SF_URL}/software-factory-${SF_REL}.third-party.md5")
ROLE_MD5=$(cat ./image/third_party_tools | md5sum -)
if [ "${IMAGE_MD5}" == "${UPSTREAM_MD5}" ]; then
    deflate_upstream
else
    [ -z "$SKIP_BUILD" ] && build
fi;

install

echo "Success."
