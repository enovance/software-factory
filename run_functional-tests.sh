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
bash rpm-test-requirements.sh

REFARCH="${1:-1node-allinone}"
TEST_TYPE="${2:-functional}"

if [ ${TEST_TYPE} == "openstack" ] && [ ! -n "${OS_AUTH_URL}" ]; then
    echo "Source openrc first"
    exit 1
fi

###############
# Preparation #
###############
echo "Running functional-tests with this HEAD"
display_head
prepare_artifacts
checkpoint "Running tests on $(hostname)"

if [ ${TEST_TYPE} == "openstack" ]; then
    export BUILD_QCOW=1
    which ansible-playbook &> /dev/null || sudo pip install ansible
    heat stack-delete sf_stack &> /dev/null
    clean_nodepool_tenant
else
    lxc_stop
fi

[ -z "${KEEP_GLANCE_IMAGE}" ] && build_image

# nosetests should run without a proxy, otherwise REST APIs on the LXC env might
# not be accessible
unset http_proxy
unset https_proxy

case "${TEST_TYPE}" in
    "functional")
        lxc_init
        run_bootstraps
        run_serverspec_tests
        run_functional_tests
        run_it_jenkins_ci
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
        heat_stop
        heat_init
        heat_wait
        run_heat_bootstraps
        run_functional_tests
        run_it_openstack
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
