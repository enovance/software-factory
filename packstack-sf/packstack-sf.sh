#!/bin/bash

set -ex

[ "${UID}" != "0" ] && exit -1

PUPPET_MODULE_PATH="--modulepath=/etc/puppetsf/modules --environment sf"
DOMAIN=tests.dom
BUILD=/root/sf-conf

ORIG=$(cd $(dirname $0); pwd)

cd $ORIG
. functions.sh

if [ ! -f "/etc/puppetsf/hiera/sfcreds.yaml" ]; then
    ln -sf /etc/puppetsf/hiera.yaml /etc/puppet/hiera.yaml
    sed -i 's/puppet\/module/puppetsf\/module/' /etc/puppet/hiera.yaml
    export SF_SUFFIX=tests.dom
    echo "$0 generate conf in $BUILD"
    set +x
    generate_keys
    generate_creds_yaml
    generate_sfconfig
    generate_apache_cert
    prepare_etc_puppet
    set -x
fi

### Tmp fixes starts here
cat << EOF > /etc/puppetsf/hiera/hosts.yaml
hosts:
  localhost:
    ip: 127.0.0.1
  puppetmaster.tests.dom:
    ip: 127.0.0.1
    host_aliases: [puppetmaster]
  mysql.tests.dom:
    ip: 127.0.0.1
    host_aliases: [mysql]
  jenkins.tests.dom:
    ip: 127.0.0.1
    host_aliases: [jenkins]
  redmine.tests.dom:
    ip: 127.0.0.1
    host_aliases: [redmine]
  api-redmine.tests.dom:
    ip: 127.0.0.1
  gerrit.tests.dom:
    ip: 127.0.0.1
    host_aliases: [gerrit]
  managesf.tests.dom:
    ip: 127.0.0.1
    host_aliases: [managesf, auth.tests.dom, tests.dom]
  slave.tests.dom:
    ip: 127.0.0.1
    host_aliases: [slave]
EOF

function puppet_apply {
    set +e
    puppet apply --test $PUPPET_MODULE_PATH $1
    [ "$?" != 2 ] && exit 1
}

STEP1=/tmp/step1_base.pp
cat << EOF | tee $STEP1
node default {
  # these are imported from modules/base
  include disable_root_pw_login
  include ssh_keys
  include postfix
  include monit
  if \$virtual != 'lxc' {
    include ntpserver
  }
  include https_cert
}
EOF
puppet_apply $STEP1

STEP2=/tmp/step2_mysql.pp
cat << EOF | tee $STEP2
node default {
  include monit
  include mysql
}
EOF
puppet_apply $STEP2

STEP3=/tmp/step3_managesf.pp
cat << EOF | tee ${STEP3}
node default {
  include monit
  include managesf
  include cauth
  include cauth_client
  include commonservices-apache
  include replication
}
EOF
puppet_apply ${STEP3}

STEP4=/tmp/step4_gerrit_redmine.pp
cat << EOF | tee ${STEP4}
node default {
  include monit
  include managesf
  include redmine
  include gerrit
}
EOF
puppet_apply ${STEP4}

STEP5=/tmp/step5_jenkins.pp
cat << EOF | tee ${STEP5}
node default {
  include monit
  include managesf
  include jenkins
  include ssh_keys_gerrit
  include jjb
  include nodepool
}
EOF
puppet_apply ${STEP5}

STEP6=/tmp/step6_etherpad.pp
cat << EOF | tee ${STEP6}
node default {
  include etherpad
  include lodgeit
}
EOF
puppet_apply ${STEP6}

exit 0
