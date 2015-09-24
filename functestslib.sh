#!/bin/bash

DISABLE_SETX=0

export SF_SUFFIX=${SF_SUFFIX:-tests.dom}
export SKIP_CLEAN_ROLES="y"

MANAGESF_URL=http://managesf.${SF_SUFFIX}

ARTIFACTS_DIR="/var/lib/sf/artifacts"
# This environment variable is set ZUUL in the jenkins job workspace
# The artifacts directory is then at the root of workspace
[ -n "$SWIFT_artifacts_URL" ] && ARTIFACTS_DIR="$(pwd)/../artifacts"

CONFDIR=/var/lib/lxc-conf

function clean_old_cache {
    # Remove directory older than 1 week (7 days)
    echo "Removing old item from cache..."
    for item in $(find /var/lib/sf/roles/upstream/* /var/lib/sf/roles/install/* -maxdepth 0 -ctime +7 | \
        grep -v "\(${SF_VER}\|${PREVIOUS_SF_VER}\)"); do
            if [ -f "${item}" ] || [ -d "${item}" ]; then
                echo ${item}
                sudo rm -Rf ${item}
            fi
    done
    echo "Done."
}

function wait_for_statement {
    local STATEMENT=$1
    local EXPECT_RETURN_CODE=${2-0}
    local MAX_RETRY=${3-40}
    local SLEEP_TIME=${4-5}
    while true; do
        eval "${STATEMENT}" &> /dev/null
        if [ "$?" == "${EXPECT_RETURN_CODE}" ]; then
            break
        fi
        sleep ${SLEEP_TIME}
        let MAX_RETRY=MAX_RETRY-1
        if [ "${MAX_RETRY}" == 0 ]; then
            echo "Following statement didn't happen: [$STATEMENT]"
            return 1
        fi
    done
}

function prepare_artifacts {
    [ -d ${ARTIFACTS_DIR} ] && sudo rm -Rf ${ARTIFACTS_DIR}
    sudo mkdir -p ${ARTIFACTS_DIR}
    USER=$(whoami)
    sudo chown -R $USER:$USER ${ARTIFACTS_DIR}
    sudo chmod -R 755 ${ARTIFACTS_DIR}
    set +x
    if [ -n ${SWIFT_artifacts_URL} ]; then
        echo "Logs will be available here: $SWIFT_artifacts_URL"
    else
        echo "Logs will be available here: ${ARTIFACTS_DIR}"
    fi
    set -x
}

function scan_and_configure_knownhosts {
    local ip=192.168.135.54
    rm -f "$HOME/.ssh/known_hosts"
    RETRIES=0
    echo " [+] Starting ssh-keyscan on $ip:22"
    while true; do
        KEY=`ssh-keyscan -p 22 $ip`
        if [ "$KEY" != ""  ]; then
            ssh-keyscan $ip | tee -a "$HOME/.ssh/known_hosts"
            echo "  -> $role:22 is up!"
            return 0
        fi
        let RETRIES=RETRIES+1
        [ "$RETRIES" == "40" ] && return 1
        echo "  [E] ssh-keyscan on $ip:22 failed, will retry in 1 seconds (attempt $RETRIES/40)"
        sleep 1
    done
}

function get_logs {
    #This delay is used to wait a bit before fetching log file from hosts
    #in order to not avoid so important logs that can appears some seconds
    #after a failure.
    sleep 5
    O=${ARTIFACTS_DIR}
    ssh -o StrictHostKeyChecking=no root@192.168.135.54 "cd puppet-bootstrapper; ./getlogs.sh"
    scp -r -o StrictHostKeyChecking=no root@192.168.135.54:/tmp/logs/* $O/

    # Retrieve mariadb log
    mkdir -p ${O}/mysql
    scp -r -o StrictHostKeyChecking=no root@192.168.135.54:/var/log/mariadb/mariadb.log ${O}/mysql

    for i in managesf; do
        mkdir -p ${O}/$i/system
        sudo cp -f /var/lib/lxc/$i/rootfs/var/log/{messages,cloud-init*} ${O}/$i/system
    done
}

function host_debug {
    set +x
    sudo dmesg -c > ${ARTIFACTS_DIR}/host_debug_dmesg
    ps aufx >> ${ARTIFACTS_DIR}/host_debug_ps-aufx
    free -m | tee -a ${ARTIFACTS_DIR}/host_debug_free
    sudo df -h | tee -a ${ARTIFACTS_DIR}/host_debug_df
    [ ${DISABLE_SETX} -eq 0 ] && set -x
}

function display_head {
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    git log -n 1
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo
}

function pre_fail {
    set -x
    DISABLE_SETX=1
    echo "$(hostname) FAIL to run functionnal tests of this change:"
    display_head

    checkpoint "FAIL: $1"
    host_debug
    checkpoint "host_debug"
    get_logs
    checkpoint "get-logs"
    publish_artifacts
    checkpoint "publish-artifacts"
    exit 1
}

function waiting_stack_created {
    local stackname=$1
    RETRIES=0
    while true; do
        heat stack-list | grep -i $stackname | grep -i fail
        [ "$?" -eq "0" ] && {
            echo "Stack creation has failed ..."
            # TODO: get the logs (heat stack-show)
            heat_stop
            exit 1
        }
        heat stack-list | grep -i $stackname | grep -i create_complete
        [ "$?" -eq "0" ] && break
        let RETRIES=RETRIES+1
        [ "$RETRIES" == "40" ] && exit 1
        sleep 60
    done
}

function wait_for_bootstrap_done {
    ssh -o StrictHostKeyChecking=no root@192.168.135.54 "cd puppet-bootstrapper; exec ./bootstrap.sh"
    return $?
}

function prepare_functional_tests_venv {
    echo "$(date) ======= Prepare functional tests venv ======="
    if [ ! -d /var/lib/sf/venv ]; then
        sudo virtualenv /var/lib/sf/venv
        sudo chown -R ${USER} /var/lib/sf/venv
    fi
    (
        . /var/lib/sf/venv/bin/activate
        pip install --upgrade pip
        pip install -r ${PYSFLIB_CLONED_PATH}/requirements.txt
        pip install -r ${CAUTH_CLONED_PATH}/requirements.txt
        pip install -r ${MANAGESF_CLONED_PATH}/requirements.txt
        pip install --upgrade setuptools pbr pycrypto
        pip install pyOpenSSL ndg-httpsclient pyasn1 nose git-review
        cd ${PYSFLIB_CLONED_PATH}; python setup.py install
        cd ${CAUTH_CLONED_PATH}; python setup.py install
        cd ${MANAGESF_CLONED_PATH}; python setup.py install
    ) > ${ARTIFACTS_DIR}/venv_prepartion.output
    checkpoint "/var/lib/sf/venv/ prep"
}

function reset_etc_hosts_dns {
    (
        set -x
        host=$1
        ip=$2
        grep -q " ${host}" /etc/hosts || {
            # adds to /etc/hosts if not already defined
            echo "${ip} ${host}" | sudo tee -a /etc/hosts
        } && {
            # else sed in-place
            sudo sed -i "s/^.* ${host}/${ip} ${host}/" /etc/hosts
        }
    ) &> ${ARTIFACTS_DIR}/etc_hosts.log
}

function run_functional_tests {
    echo "$(date) ======= Starting functional tests ========="
    echo "[+] Adds tests.dom to /etc/hosts"
    reset_etc_hosts_dns 'tests.dom' 192.168.135.54
    for host in puppetmaster redmine mysql gerrit jenkins managesf; do
        reset_etc_hosts_dns "${host}.tests.dom" 192.168.135.54
    done
    echo "[+] Avoid ssh error"
    cat << EOF > ~/.ssh/config
Host *.tests.dom
    UserKnownHostsFile no
    StrictHostKeyChecking no
EOF
    chmod 0600 ~/.ssh/config
    echo "[+] Fetch bootstrap data"
    rm -Rf sf-bootstrap-data
    scp -r root@puppetmaster.tests.dom:sf-bootstrap-data .
    echo "[+] Fetch tests.dom ssl cert"
    scp -r root@puppetmaster.tests.dom:/etc/pki/ca-trust/extracted/openssl/ca-bundle.trust.crt /var/lib/sf/venv/lib/python2.7/site-packages/requests/cacert.pem
    cp /var/lib/sf/venv/lib/python2.7/site-packages/requests/cacert.pem /var/lib/sf/venv/lib/python2.7/site-packages/pip/_vendor/requests/cacert.pem
    echo "[+] Run tests"
    sudo rm -Rf /tmp/debug
    . /var/lib/sf/venv/bin/activate
    checkpoint "functional tests running..."
    nosetests --with-xunit -v tests/functional 2>&1 | tee ${ARTIFACTS_DIR}/functional-tests.output
    RES=${PIPESTATUS[0]}
    mv /tmp/debug ${ARTIFACTS_DIR}/functional_tests.debug
    deactivate
    return $RES
}

function run_puppet_allinone_tests {
    echo "$(date) ======= Starting Puppet all in one tests ========="
    ssh -o StrictHostKeyChecking=no root@192.168.135.54 \
            "puppet master --compile allinone --environment=sf" 2>&1 &> ${ARTIFACTS_DIR}/functional-tests.output
    return ${PIPESTATUS[0]}
}

function run_tests {
    prepare_functional_tests_venv
    checkpoint "prepare_venv"
    scan_and_configure_knownhosts || pre_fail "Can't SSH"
    checkpoint "scan_and_configure_knownhosts"
    wait_for_bootstrap_done || pre_fail "Bootstrap did not complete"
    checkpoint "wait_for_bootstrap_done"
    run_functional_tests || pre_fail "Functional tests failed"
    checkpoint "run_functional_tests"
    run_puppet_allinone_tests || pre_fail "Puppet all in one tests failed"
    checkpoint "run_puppet_allinone_tests"
}

function run_backup_restore_tests {
    r=$1
    type=$2
    if [ "$type" == "provision" ]; then
        scan_and_configure_knownhosts
        wait_for_bootstrap_done || pre_fail "Bootstrap did not complete"
        # Run server spec to be more confident
        run_serverspec || pre_fail "Serverspec failed"
        # Start the provisioner
        ./tools/provisioner_checker/run.sh provisioner
        # Create a backup
        ssh -o StrictHostKeyChecking=no root@192.168.135.54 "sfmanager --url ${MANAGESF_URL} --auth-server-url ${MANAGESF_URL} --auth user1:userpass backup start"
        sleep 10
        # Fetch the backup
        ssh -o StrictHostKeyChecking=no root@192.168.135.54 "sfmanager --url ${MANAGESF_URL} --auth-server-url ${MANAGESF_URL} --auth user1:userpass backup get"
        scp -o  StrictHostKeyChecking=no root@192.168.135.54:sf_backup.tar.gz /tmp
        # We assume if we cannot move the backup file
        # we need to stop right now
        return $?
    fi
    if [ "$type" == "check" ]; then
        scan_and_configure_knownhosts || pre_fail "Can't SSH"
        # Run server spec to be more confident
        run_serverspec || pre_fail "Serverspec failed"
        # Restore backup
        scp -o  StrictHostKeyChecking=no /tmp/sf_backup.tar.gz root@192.168.135.54:/root/
        ssh -o StrictHostKeyChecking=no root@192.168.135.54 "sfmanager --url ${MANAGESF_URL} --auth-server-url ${MANAGESF_URL} --auth user1:userpass backup restore --filename sf_backup.tar.gz"
        # Start the checker
        sleep 60
        ./tools/provisioner_checker/run.sh checker
        return $?
    fi
}

function clear_mountpoint {
    # Clean mountpoints
    grep '\/var.*proc' /proc/mounts | awk '{ print $2 }' | while read mountpoint; do
        echo "[+] UMOUNT ${mountpoint}"
        sudo umount ${mountpoint} || echo "umount failed";
    done
    grep '\/var.*lxc' /proc/mounts | awk '{ print $2 }' | while read mountpoint; do
        echo "[+] UMOUNT ${mountpoint}"
        sudo umount ${mountpoint} || echo "umount failed";
    done
}

START=$(date '+%s')

function checkpoint {
    set +x
    NOW=$(date '+%s')
    ELAPSED=$(python -c "print('%03.2fmin' % (($NOW - $START) / 60.0))")
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "$ELAPSED - $* ($(date))" | sudo tee -a ${ARTIFACTS_DIR}/tests_profiling
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    START=$(date '+%s')
    [ ${DISABLE_SETX} -eq 0 ] && set -x
}
