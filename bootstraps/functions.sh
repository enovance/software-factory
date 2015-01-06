#!/bin/bash
#
# copyright (c) 2014 enovance sas <licensing@enovance.com>
#
# licensed under the apache license, version 2.0 (the "license"); you may
# not use this file except in compliance with the license. you may obtain
# a copy of the license at
#
# http://www.apache.org/licenses/license-2.0
#
# unless required by applicable law or agreed to in writing, software
# distributed under the license is distributed on an "as is" basis, without
# warranties or conditions of any kind, either express or implied. see the
# license for the specific language governing permissions and limitations
# under the license.

set -e
set -x

ROLES="puppetmaster"
ROLES="$ROLES mysql"
ROLES="$ROLES redmine"
ROLES="$ROLES gerrit"
ROLES="$ROLES managesf"
ROLES="$ROLES jenkins"
ROLES="$ROLES slave"

PUPPETIZED_ROLES=$(echo $ROLES | sed -e s/puppetmaster// -e s/slave//)

SFTMP=/tmp/sf-conf/
SFCONFIGFILE=$SFTMP/sfconfig.yaml
INITIAL=${INITIAL:-yes}

function hash_password {
    python -c "import crypt, random, string; salt = '\$6\$' + ''.join(random.choice(string.letters + string.digits) for _ in range(16)) + '\$'; print crypt.crypt('$1', salt)"
}

function generate_sfconfig {
    [ -d $SFTMP ] && sudo rm -Rf $SFTMP
    mkdir $SFTMP
    cp ../sfconfig.yaml $SFCONFIGFILE

    # Set and generated admin password
    DEFAULT_ADMIN_USER=$(cat ../sfconfig.yaml | grep '^admin_name:' | awk '{ print $2 }')
    DEFAULT_ADMIN_PASSWORD=$(cat ../sfconfig.yaml | grep '^admin_password:' | awk '{ print $2 }')
    ADMIN_USER=${ADMIN_USER:-${DEFAULT_ADMIN_USER}}
    ADMIN_PASSWORD=${ADMIN_PASSWORD:-${DEFAULT_ADMIN_PASSWORD}}
    ADMIN_PASSWORD_HASHED=$(hash_password "${ADMIN_PASSWORD}")
    sed -i "s/^admin_name:.*/admin_name: ${ADMIN_USER}/" $SFCONFIGFILE
    sed -i "s/^admin_password:.*/admin_password: ${ADMIN_PASSWORD}/" $SFCONFIGFILE
    echo "admin_password_hashed: \"${ADMIN_PASSWORD_HASHED}\"" >> $SFCONFIGFILE
}

function getip_from_yaml {
    cat ../hosts.yaml  | grep -A 1 "^  $1" | grep 'ip:' | cut -d: -f2 | sed 's/ *//g'
}

function ansible_bootstrap {
    if [ ! -d ansible/group_vars ]; then
        mkdir ansible/group_vars
    fi
    echo "puppetmaster_ip: $(getip_from_yaml puppetmaster)" > ansible/group_vars/all
    echo "[all]" > ${BUILD}/hosts
    for role in ${PUPPETIZED_ROLES}; do
        getip_from_yaml ${role} >> ${BUILD}/hosts
    done
    ansible-playbook -vvvv -f 1 -i ${BUILD}/hosts ansible/bootstrap.yml
    echo "Ansible return-code is $?"
}

function generate_random_pswd {
    # The sed character replacement makes the base64-string URL safe; for example required by lodgeit
    echo `dd if=/dev/urandom bs=1 count=$1 2>/dev/null | base64 -w $1 | head -n1 | sed -e 's#/#_#g;s#\+#_#g'`
}

function generate_api_key {
    out=""
    while [ ${#out} -lt 40 ]; do
            out=$out`echo "obase=16; $RANDOM" | bc`
    done

    out=${out:0:40}
    echo $out | awk '{print tolower($0)}'
}

function generate_creds_yaml {
    OUTPUT=${BUILD}/hiera
    mkdir -p ${OUTPUT}
    cp sfcreds.yaml ${OUTPUT}/
    # MySQL password for services
    MYSQL_ROOT_SECRET=$(generate_random_pswd 8)
    REDMINE_MYSQL_SECRET=$(generate_random_pswd 8)
    GERRIT_MYSQL_SECRET=$(generate_random_pswd 8)
    ETHERPAD_MYSQL_SECRET=$(generate_random_pswd 8)
    LODGEIT_MYSQL_SECRET=$(generate_random_pswd 8)
    sed -i "s#MYSQL_ROOT_PWD#${MYSQL_ROOT_SECRET}#" ${OUTPUT}/sfcreds.yaml
    sed -i "s#REDMINE_SQL_PWD#${REDMINE_MYSQL_SECRET}#" ${OUTPUT}/sfcreds.yaml
    sed -i "s#GERRIT_SQL_PWD#${GERRIT_MYSQL_SECRET}#" ${OUTPUT}/sfcreds.yaml
    sed -i "s#ETHERPAD_SQL_PWD#${ETHERPAD_MYSQL_SECRET}#" ${OUTPUT}/sfcreds.yaml
    sed -i "s#LODGEIT_SQL_PWD#${LODGEIT_MYSQL_SECRET}#" ${OUTPUT}/sfcreds.yaml
    # Default authorized ssh keys on each node
    JENKINS_PUB="$(cat ${OUTPUT}/../data/jenkins_rsa.pub | cut -d' ' -f2)"
    sed -i "s#JENKINS_PUB_KEY#${JENKINS_PUB}#" ${OUTPUT}/sfcreds.yaml
    # Redmine part
    REDMINE_API_KEY=$(generate_api_key)
    sed -i "s#REDMINE_API_KEY#${REDMINE_API_KEY}#" ${OUTPUT}/sfcreds.yaml
    # Gerrit part
    GERRIT_EMAIL_PK=$(generate_random_pswd 32)
    GERRIT_TOKEN_PK=$(generate_random_pswd 32)
    GERRIT_SERV_PUB="$(cat ${OUTPUT}/../data/gerrit_service_rsa.pub | cut -d' ' -f2)"
    GERRIT_ADMIN_PUB_KEY="$(cat ${OUTPUT}/../data/gerrit_admin_rsa.pub | cut -d' ' -f2)"
    sed -i "s#GERRIT_EMAIL_PK#${GERRIT_EMAIL_PK}#" ${OUTPUT}/sfcreds.yaml
    sed -i "s#GERRIT_TOKEN_PK#${GERRIT_TOKEN_PK}#" ${OUTPUT}/sfcreds.yaml
    sed -i "s#GERRIT_SERV_PUB_KEY#${GERRIT_SERV_PUB}#" ${OUTPUT}/sfcreds.yaml
    sed -i "s#GERRIT_ADMIN_PUB_KEY#${GERRIT_ADMIN_PUB_KEY}#" ${OUTPUT}/sfcreds.yaml
    # Jenkins part
    JENKINS_USER_PASSWORD="${JUP}"
    sed -i "s#JENKINS_USER_PASSWORD#${JENKINS_USER_PASSWORD}#" ${OUTPUT}/sfcreds.yaml
    # Etherpad part
    ETHERPAD_SESSION_KEY=$(generate_random_pswd 10)
    sed -i "s#ETHERPAD_SESSION_KEY#${ETHERPAD_SESSION_KEY}#" ${OUTPUT}/sfcreds.yaml
    # Lodgeit/Paste part
    LODGEIT_SESSION_KEY=$(generate_random_pswd 10)
    sed -i "s#LODGEIT_SESSION_KEY#${LODGEIT_SESSION_KEY}#" ${OUTPUT}/sfcreds.yaml
}

function scan_and_configure_knownhosts {
    local fqdn=$1.${SF_SUFFIX}
    local hostname=$1
    local ip=$2
    local port=$3
    RETRIES=0
    echo " [+] Starting ssh-keyscan on $fqdn:$port"
    while true; do
        KEY=`ssh-keyscan -p $port $fqdn 2> /dev/null`
        if [ "$KEY" != ""  ]; then
                # fix ssh-keyscan bug for 2 ssh server on different port
                if [ "$port" != "22" ]; then
                    ssh-keyscan -p $port $fqdn 2> /dev/null | sed "s/$fqdn/[$fqdn]:$port,[$ip]:$port,[$hostname]:$port/" >> "$HOME/.ssh/known_hosts"
                else
                    ssh-keyscan $fqdn 2> /dev/null | sed "s/$fqdn/$fqdn,$ip,$hostname/" >> "$HOME/.ssh/known_hosts"
                fi
                echo "  -> $fqdn:$port is up!"
                break
        fi

        let RETRIES=RETRIES+1
        [ "$RETRIES" == "40" ] && break
        echo "  [E] ssh-keyscan on $fqdn:$port failed, will retry in 10 seconds (attempt $RETRIES/40)"
        sleep 10
    done
}

function generate_keys {
    OUTPUT=${BUILD}/data
    mkdir -p ${OUTPUT}
    # Service key is used to allow puppetmaster root to
    # connect on other node as root
    ssh-keygen -N '' -f ${OUTPUT}/service_rsa
    cp ${OUTPUT}/service_rsa /root/.ssh/id_rsa
    cp ${OUTPUT}/service_rsa.pub /root/.ssh/id_rsa.pub
    ssh-keygen -N '' -f ${OUTPUT}/jenkins_rsa
    ssh-keygen -N '' -f ${OUTPUT}/gerrit_service_rsa
    ssh-keygen -N '' -f ${OUTPUT}/gerrit_admin_rsa
    # generating keys for cauth
    openssl genrsa -out ${OUTPUT}/privkey.pem 1024
    openssl rsa -in ${OUTPUT}/privkey.pem -out ${OUTPUT}/pubkey.pem -pubout
}

function install_master_ssh_key {
    for role in ${ROLES}; do
        [ "${role}" == "puppetmaster" ] && continue
        local ip=$(getip_from_yaml ${role})
        scan_and_configure_knownhosts "$role" ${ip} 22
        local retries=20
        while [ $retries -gt 0 ]; do
            sshpass -p $TEMP_SSH_PWD ssh-copy-id ${ip} && break
            let retries=retries-1
        done
        [ $retries -gt 0 ] || exit -1
    done
}

function prepare_etc_puppet {
    DATA=${BUILD}/data
    HIERA=${BUILD}/hiera
    cp /root/hosts.yaml /etc/puppet/hiera/sf
    cp /root/sfconfig.yaml /etc/puppet/hiera/sf
    cp $HIERA/sfcreds.yaml /etc/puppet/hiera/sf
    TMP_VERSION=$(grep ^VERS= /var/lib/edeploy/conf | cut -d"=" -f2)
    if [ -z "${TMP_VERSION}" ]; then
        echo "FAIL: could not find edeploy version in /var/lib/edeploy/conf..."
        exit -1
    fi
    echo "sf_version: $(echo ${TMP_VERSION} | cut -d'-' -f2)" > /etc/puppet/hiera/sf/sf_version.yaml
    cp $DATA/service_rsa /etc/puppet/environments/sf/modules/ssh_keys/files/
    cp $DATA/jenkins_rsa /etc/puppet/environments/sf/modules/jenkins/files/
    cp $DATA/jenkins_rsa /etc/puppet/environments/sf/modules/zuul/files/
    cp $DATA/gerrit_admin_rsa /etc/puppet/environments/sf/modules/jenkins/files/
    cp $DATA/gerrit_service_rsa /etc/puppet/environments/sf/modules/gerrit/files/
    cp $DATA/gerrit_service_rsa.pub /etc/puppet/environments/sf/modules/gerrit/files/
    cp $DATA/gerrit_admin_rsa /etc/puppet/environments/sf/modules/managesf/files/
    cp $DATA/service_rsa /etc/puppet/environments/sf/modules/managesf/files/
    cp $DATA/gerrit_admin_rsa /etc/puppet/environments/sf/modules/jjb/files/
    cp $DATA/privkey.pem /etc/puppet/environments/sf/modules/cauth/files/
    cp $DATA/pubkey.pem /etc/puppet/environments/sf/modules/cauth/files/
    chown -R puppet:puppet /etc/puppet/environments/sf
    chown -R puppet:puppet /etc/puppet/hiera/sf
    chown -R puppet:puppet /var/lib/puppet
}
