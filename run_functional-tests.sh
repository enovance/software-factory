#!/bin/bash

# Make sure this is run under sudo
if [ -z "$SUDO_COMMAND" ] || [ "$UID" != "0" ]; then
    exec sudo $0 $*
fi

. ./role_configrc

CONTAINER_ROOT=/srv/software-factory-${SF_REL}
CLEAN_CENTOS="${BUILD_DIR}/software-factory-${SF_REL}"

if [ ! -d "${CLEAN_CENTOS}" ]; then
    echo "Build image"
    ./build_image.sh
fi

set -ex
function checkpoint {
    set +x
    echo -e "\n[$(date "+%Y-%m-%d %H:%M:%S")] \033[92m=== $* ===\033[0m"
    set -x
}

function container_exec {
    if [ -z "${CONTAINER_PID}" ]; then
        echo "CONTAINER_PID is null"
        exit 1
    fi
    nsenter --target ${CONTAINER_PID} -p -m -n -i -u -- $*
}

function prepare_env {
    PYSFLIB="/var/lib/sf/pysflib"
    checkpoint "Install pysflib virtual env to $PYSFLIB"
    which git || yum install -y git
    if [ ! -d "${PYSFLIB}" ]; then
        mkdir -p $(dirname $PYSFLIB) || true
        git clone http://softwarefactory.enovance.com/r/pysflib $PYSFLIB
    fi
    which virtualenv || yum install -y python-virtualenv
    if [ ! -d "${PYSFLIB}/.venv" ]; then
        virtualenv ${PYSFLIB}/.venv
        (
            yum install -y gcc openldap-devel
            cd ${PYSFLIB}
            . ./.venv/bin/activate
            pip install --upgrade setuptools
            pip install -r ${PYSFLIB}/requirements.txt
            python setup.py install
        )
    fi
    MANAGESF="/var/lib/sf/managesf"
    checkpoint "Install managesf"
    if [ ! -d "${MANAGESF}" ]; then
        mkdir -p $(dirname $MANAGESF) || true
        git clone http://softwarefactory.enovance.com/r/managesf $MANAGESF
        (
            cd $MANAGESF
            . ${PYSFLIB}/.venv/bin/activate
            pip install --upgrade pycrypto
            pip install -r ${MANAGESF}/requirements.txt
            python setup.py install
        )
    fi
}



function start {
    # Make sure no nspawn process are running
    if [ "$(pidof systemd-nspawn)" != "" ]; then
        echo "Stalling systemd-nspawn process..."
        exit 1
    fi
    [ -d ${CONTAINER_ROOT} ] || mkdir -p ${CONTAINER_ROOT}


    checkpoint "Copy fresh install to ${CONTAINER_ROOT}/"
    rsync -a --delete ${CLEAN_CENTOS}/ ${CONTAINER_ROOT}/

    checkpoint "Start the container with systemd-nspawn -M sfcentos"
    ip netns add sf
    ip netns exec sf systemd-nspawn -b -D ${CONTAINER_ROOT}/ -M sfcentos > /dev/null 2> /dev/null &
    sleep 1

    checkpoint "Wait for systemd container process"
    NSPAWN_PID=$(pidof systemd-nspawn)
    set +ex
    for i in $(seq 42); do
        CONTAINER_PID=$(ps -o pid --ppid ${NSPAWN_PID} --noheaders | sed 's/ //g')
        [ -z "${CONTAINER_PID}" ] || break
        sleep 0.5
    done
    set -ex

    checkpoint "Configure network"
    ip link add sf0 type veth peer name sf1
    # initiate the host side
    ip link set sf0 up
    # initiate the container side
    ip link set sf1 netns sf up

    # configure network
    ip addr add 192.168.242.1/30 dev sf0
    ip netns exec sf ip addr add 192.168.242.2/30 dev sf1
    ip netns exec sf ip route add default via 192.168.242.1 dev sf1

    # enable routing
    echo 1 | tee /proc/sys/net/ipv4/ip_forward
    ext_if=$(ip route get 8.8.8.8 | grep 'dev' | awk '{ print $5 }')
    iptables -I POSTROUTING -t nat -s 192.168.242.2/32 -o ${ext_if} -j MASQUERADE
    iptables -I FORWARD -i sf0 -o ${ext_if} -j ACCEPT
    iptables -I FORWARD -i ${ext_if} -o sf0 -j ACCEPT

    # configure resolv.conf
    cat /etc/resolv.conf > ${CONTAINER_ROOT}/etc/resolv.conf

    # Check network...
    checkpoint "Check connectivity"
    ip netns exec sf ping -c 1 8.8.8.8
}

function stop {
    set +e
    checkpoint "Stop"
    ip netns delete sf
    ext_if=$(ip route get 8.8.8.8 | grep 'dev' | awk '{ print $5 }')
    iptables -D POSTROUTING -t nat -s 192.168.242.2/32 -o ${ext_if} -j MASQUERADE
    iptables -D FORWARD -i sf0 -o ${ext_if} -j ACCEPT
    iptables -D FORWARD -i ${ext_if} -o sf0 -j ACCEPT
    pidof systemd-nspawn && kill -9 $(pidof systemd-nspawn)
    sleep 0.5
    pidof systemd-nspawn && kill -9 $(pidof systemd-nspawn)
    rm -f nohup.out
    umount ${CONTAINER_ROOT}/proc
    umount ${CONTAINER_ROOT}/dev
    umount -R ${CONTAINER_ROOT}
    umount ${CONTAINER_ROOT}
    # clean overlay upper
    #rm -Rf /srv/centos7_overlay/upper/*
    set -e
}

if [ "$1" == "stop" ]; then
    stop
    exit
fi

function install {
    checkpoint "Run packstack-sf"
    container_exec /root/packstack-sf/packstack-sf.sh || true

    # spawn a debuging shell
    [ -z "${DEBUG}" ] || container_exec /bin/bash
}

function test {
    set +e

    checkpoint "Configure domain name"
    grep -q tests.dom /etc/hosts || echo 192.168.242.2 tests.dom | tee -a /etc/hosts

    checkpoint "Test"
    echo "[+] Check jenkins is running"
    curl -I 192.168.242.2:8082/ | grep X-Jenkins || TEST_RESULT=1

    echo "[+] Check zuul is listening"
    ip netns exec sf netstat -nl | grep 4730 || TEST_RESULT=1

    echo "[+] Get packstack generated file"
    [ -d "build/" ] && rm -Rf build/
    cp -R /srv/software-factory-1.0.3/root/sf-conf/ build/

    echo "[+] Run functional tests..."
    (cd tests/functional; . ${PYSFLIB}/.venv/bin/activate; nosetests -sv)
}

prepare_env
stop
start
install

TEST_RESULT=0
test

if [ -z "${DEBUG}" ]; then
    stop
    # Restore the container root and show modified files
    [ ! -z "${VERBOSE}" ] && VERBOSE="-v"
    checkpoint "Clean ${CONTAINER_ROOT}"
    rsync -a ${VERBOSE} --delete ${CLEAN_CENTOS}/ ${CONTAINER_ROOT}/
    exit ${TEST_RESULT}
fi

set +x
echo "Container is running: ${CONTAINER_ROOT}"
machinectl status sfcentos


echo "Join the container with:"
echo "nsenter --target ${CONTAINER_PID} -p -m -n -i -u"

exit ${TEST_RESULT}
