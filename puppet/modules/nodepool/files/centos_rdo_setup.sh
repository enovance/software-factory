#!/bin/bash

. base.sh

sudo dd if=/dev/zero of=/srv/swap count=4000 bs=1M
sudo chmod 600 /srv/swap
sudo mkswap /srv/swap
grep swap /etc/fstab || echo "/srv/swap none swap sw 0 0" | sudo tee -a /etc/fstab

# TODO: support selinux activated...
sudo sed -i 's/^.*SELINUX=.*$/SELINUX=disabled/' /etc/selinux/config

#sudo yum install -y https://www.rdoproject.org/repos/rdo-release.rpm
sudo yum install -y https://repos.fedorapeople.org/repos/openstack/openstack-kilo/rdo-release-kilo-1.noarch.rpm
#sudo yum install -y https://repos.fedorapeople.org/repos/openstack/openstack-kilo/testing/rdo-release-kilo-1.noarch.rpm
#sudo yum install -y http://buildlogs.centos.org/centos/7/cloud/x86_64/openstack-kilo/centos-release-openstack-kilo-1-2.el7.noarch.rpm

sudo yum install -y openstack-packstack puppet libvirt qemu libguestfs erlang-sd_notify             \
    openstack-cinder openstack-dashboard openstack-glance openstack-keystone openstack-neutron      \
    openstack-neutron-common openstack-neutron-ml2 openstack-neutron-openvswitch openstack-nova-api \
    openstack-nova-cert openstack-nova-common openstack-nova-compute openstack-nova-conductor       \
    openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler openstack-packstack   \
    openstack-packstack-puppet openstack-puppet-modules openstack-selinux openstack-utils           \
    python2-django-openstack-auth openstack-swift python-oslo-cache openstack-heat-api

sudo yum install -y memcached mariadb-galera-server numpy-f2py tcl tk xorg-x11-font-utils nmap-ncat \
    perl-macros perl-Time-HiRes device-mapper-event device-mapper-event-libs usbredir wxGTK         \
    ruby ruby-augeas rubygem-json rabbitmq-server radvd pytz python-XStatic python-websockify       \
    python-urwid python-suds python-stevedore python-sqlalchemy python-qpid-common python-pbr       \
    python-lxml python-ldap python-ldappool python-kombu python-keystonemiddleware python-heatclient \
    python-glance-store python-greenlet python-futures python-eventlet gtk2 hiera hivex httpd       \
    httpd-tools graphviz graphite2 gnutls-dane glusterfs glusterfs-api glusterfs-libs               \
    gdk-pixbuf2 galera fuse-libs fuse facter fontawesome-fonts-web ebtables dosfstools              \
    dnsmasq-utils device-mapper-persistent-data cyrus-sasl cryptsetup conntrack-tools cairo         \
    bridge-utils bootswatch-fonts bootswatch-common blas avahi-libs attr alsa-lib apr apr-util      \
    sos python2-appdirs python2-os-client-config python-tablib python-cliff-tablib                  \
    python-openstackclient libnl python-ethtool python-configshell targetcli selinux-policy         \
    selinux-policy-targeted

sudo yum install -y erlang-appmon-R16B erlang-asn1-R16B erlang-common_test-R16B erlang-compiler-R16B        \
    erlang-compiler-R16B erlang-cosEventDomain-R16B erlang-cosEvent-R16B erlang-cosFileTransfer-R16B        \
    erlang-cosNotification-R16B erlang-cosProperty-R16B erlang-cosTime-R16B erlang-cosTransactions-R16B     \
    erlang-crypto-R16B erlang-crypto-R16B erlang-debugger-R16B erlang-dialyzer-R16B erlang-diameter-R16B    \
    erlang-edoc-R16B erlang-eldap-R16B erlang-erl_docgen-R16B erlang-erl_interface-R16B erlang-erts-R16B    \
    erlang-erts-R16B erlang-et-R16B erlang-eunit-R16B erlang-examples-R16B erlang-gs-R16B erlang-hipe-R16B  \
    erlang-hipe-R16B erlang-ic-R16B erlang-inets-R16B erlang-jinterface-R16B erlang-kernel-R16B             \
    erlang-kernel-R16B erlang-megaco-R16B erlang-mnesia-R16B erlang-observer-R16B erlang-odbc-R16B          \
    erlang-orber-R16B erlang-os_mon-R16B erlang-otp_mibs-R16B erlang-parsetools-R16B erlang-percept-R16B    \
    erlang-pman-R16B erlang-public_key-R16B erlang-R16B erlang-reltool-R16B erlang-runtime_tools-R16B       \
    erlang-sasl-R16B erlang-sd_notify erlang-snmp-R16B erlang-ssh-R16B erlang-ssl-R16B erlang-stdlib-R16B   \
    erlang-stdlib-R16B erlang-syntax_tools-R16B erlang-syntax_tools-R16B erlang-test_server-R16B            \
    erlang-toolbar-R16B erlang-tools-R16B erlang-tv-R16B erlang-typer-R16B erlang-webtool-R16B              \
    erlang-wx-R16B erlang-xmerl-R16B

# fix hiera issue (BZ#1284978)
#sudo yum install -y \
#    http://buildlogs.centos.org/centos/7/cloud/x86_64/openstack-kilo/openstack-packstack-2015.1-0.13.dev1616.g5526c38.el7.noarch.rpm            \
#    http://buildlogs.centos.org/centos/7/cloud/x86_64/openstack-kilo/openstack-packstack-puppet-2015.1-0.13.dev1616.g5526c38.el7.noarch.rpm

# Install sf requirements
sudo yum install -y git python-augeas bridge-utils curl lxc wget swig python-devel python-pip graphviz python-yaml openssl-devel libffi-devel pigz mysql-devel openldap-devel qemu-img libvirt-daemon-lxc git-review

sudo pip install flake8 bash8 ansible
sudo pip install -U tox==1.6.1 Sphinx oslosphinx virtualenv restructuredtext_lint python-swiftclient
# Temporary DNS fix
echo "216.58.213.16 gerrit-releases.storage.googleapis.com" | sudo tee -a /etc/hosts
sudo mkdir -p /var/lib/sf
sudo mkdir -p /var/lib/sf/artifacts/logs
sudo chown -R jenkins:jenkins /var/lib/sf/



# sync FS, otherwise there are 0-byte sized files from the yum/pip installations
sudo sync
sudo sync

echo "Setup finished. Creating snapshot now, this will take a few minutes"
