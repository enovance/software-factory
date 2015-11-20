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

# This script will build if needed the roles for software-factory
# Then will start the SF in LXC containers
# Then will run the serverspecs and functional tests

source functestslib.sh
. role_configrc

REFARCH="${1:-1node-allinone}"
TEST_TYPE="${2:-functional}"

###############
# Preparation #
###############
echo "Running functional-tests with this HEAD"
display_head
prepare_artifacts
checkpoint "Running tests on $(hostname)"
lxc_stop
if [ ${TEST_TYPE} == "openstack" ] && [ ! -f "${IMAGE_PATH}.img.qcow3" ]; then
    export BUILD_QCOW=1
fi
build_image

case "${TEST_TYPE}" in
    "functional")
        lxc_init
        run_bootstraps
        run_serverspec_tests
        run_functional_tests
        ;;
    "backup")
        lxc_init
        run_bootstraps
        run_serverspec_tests
        run_provisioner
        run_backup_start
        lxc_stop
        lxc_init
        run_bootstraps
        run_backup_restore
        run_checker
        ;;
    "upgrade")
        SKIP_GPG=1 ./fetch_image.sh ${SF_PREVIOUS_VER} || fail "Could not fetch ${SF_PREVIOUS_VER}"
        lxc_init ${SF_PREVIOUS_VER}
        run_bootstraps
        run_provisioner
        run_upgrade
        run_checker
        run_serverspec_tests
        run_functional_tests
        ;;
    "openstack")
        glance image-create --progress --disk-format qcow2 --container-format bare --name sf-${SF_VER} --file ${IMAGE_PATH}-${SF_VER}.img.qcow2
        NET_ID=$(neutron net-list | grep 'external_network' | awk '{ print $2 }' | head)
        GLANCE_ID=$(glance image-list | grep "sf-${SF_VER}" | awk '{ print $2 }' | head)
        heat stack-create --template-file ./deploy/heat/softwarefactory.hot -P "sf_root_size=10;key_name=id_rsa;domain=tests.dom;image_id=${GLANCE_ID};ext_net_uuid=${NET_ID};flavor=m1.medium" sf_stack
        RETRY=40
        while [ $RETRY -gt 0 ]; do
            STACK_STATUS=$(heat stack-show sf_stack | grep 'stack_status ' | awk '{ print $4 }')
            [ "${STACK_STATUS}" != "CREATE_IN_PROGRESS" ] && break
            sleep 1
            let RETRY--
        done
        if [ "${STACK_STATUS}" == "CREATE_COMPLETE" ]; then
            IP=$(heat stack-show sf_stack | grep "Public address of the SF instance" | sed 's/.*: //' | awk '{ print $1 }' | sed 's/..$//')
            PASSWORD=$(heat stack-show sf_stack | grep "Administrator password for SF services" | sed 's/.*: //' | awk '{ print $1 }' | sed 's/..$//')
            ROUTER=$(neutron router-list | grep 'sf_stack' | awk '{ print $2 }')
            if [ ! -n "${IP}" ] || [ ! -n "${PASSWORD}" ] || [ ! -n "${ROUTER}" ]; then
                echo "Couldn't retrieve stack paramters..."
                exit 1
            fi
            NETNS="sudo ip netns exec qrouter-${ROUTER}"
            sleep 5;
            $NETNS ping -c 1 -w 1 ${IP} || exit -1
            RETRY=40
            while [ $RETRY -gt 0 ]; do
                $NETNS curl 192.168.200.13 | grep dashboad && break
                sleep 1
                let RETRY--
            done
            $NETNS ssh -i ${HOME}/.ssh/id_rsa ssh root@${IP} "ps afx; edeploy version"
        else
            heat stack-show sf_stack
            heat resource-list sf_stack
            exit 1
        fi
        exit 0
        ;;
    *)
        echo "[+] Unknown test type ${TEST_TYPE}"
        exit 1
        ;;
esac

DISABLE_SETX=1
checkpoint "end_tests"
# If run locally (outside of zuul) fetch logs/artifacts. If run
# through Zuul then a publisher will be used
[ -z "$SWIFT_artifacts_URL" ] && get_logs
[ -z "${DEBUG}" ] && lxc_stop
echo "$0 ${REFARCH} ${TEST_TYPE}: SUCCESS"
exit 0;
