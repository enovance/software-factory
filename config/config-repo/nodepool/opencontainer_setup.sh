#!/bin/bash

. base.sh

# Disable selinux
sudo sed -i 's/^.*SELINUX=.*$/SELINUX=permissive/' /etc/selinux/config

[ -f /etc/yum.repos.d/epel.repo ] || {
    sudo yum install -y epel-release
}

[ -f /etc/yum.repos.d/rdo-release.repo ] || {
    sudo yum install -y https://repos.fedorapeople.org/repos/openstack/openstack-mitaka/rdo-release-mitaka-3.noarch.rpm
}

which go || sudo yum install -y golang

which runc || {
    echo "[+] Installing runc"
    sudo yum install -y libseccomp-devel
    [ -d runc ] || git clone --depth 1 https://github.com/opencontainers/runc
    pushd runc
        make
        sudo cp runc /sbin
    popd
    rm -Rf runc
}

which ocitools || {
    echo "[+] Installing ocitools"
    sudo yum install -y golang
    [ -d ocitools ] || git clone --depth 1 https://github.com/opencontainers/ocitools
    pushd ocitools
        make
        sudo cp ocitools /bin
    popd
    rm -Rf ocitools
}


# sync FS, otherwise there are 0-byte sized files from the yum/pip installations
sudo sync
sudo sync

echo "SUCCESS: opencontainer-centos-7 done."
