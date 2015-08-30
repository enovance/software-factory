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

function hash_password {
    python -c "import crypt, random, string; salt = '\$6\$' + ''.join(random.choice(string.letters + string.digits) for _ in range(16)) + '\$'; print crypt.crypt('$1', salt)"
}

function generate_sfconfig {
    OUTPUT=${BUILD}/hiera
    [ -d ${OUTPUT} ] || mkdir -p ${OUTPUT}
    cp sfconfig.yaml $OUTPUT/

    # Set and generated admin password
    DEFAULT_ADMIN_USER=$(cat sfconfig.yaml | grep '^admin_name:' | awk '{ print $2 }')
    DEFAULT_ADMIN_PASSWORD=$(cat sfconfig.yaml | grep '^admin_password:' | awk '{ print $2 }')
    ADMIN_USER=${ADMIN_USER:-${DEFAULT_ADMIN_USER}}
    ADMIN_PASSWORD=${ADMIN_PASSWORD:-${DEFAULT_ADMIN_PASSWORD}}
    ADMIN_PASSWORD_HASHED=$(hash_password "${ADMIN_PASSWORD}")
    sed -i "s/^admin_name:.*/admin_name: ${ADMIN_USER}/" $OUTPUT/sfconfig.yaml
    sed -i "s/^admin_password:.*/admin_password: ${ADMIN_PASSWORD}/" $OUTPUT/sfconfig.yaml
    echo "admin_password_hashed: \"${ADMIN_PASSWORD_HASHED}\"" >> $OUTPUT/sfconfig.yaml
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
    SERVICE_PUB="$(cat ${OUTPUT}/../data/service_rsa.pub | cut -d' ' -f2)"
    sed -i "s#JENKINS_PUB_KEY#${JENKINS_PUB}#" ${OUTPUT}/sfcreds.yaml
    sed -i "s#SERVICE_PUB_KEY#${SERVICE_PUB}#" ${OUTPUT}/sfcreds.yaml
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
    JENKINS_USER_PASSWORD="$(generate_random_pswd 32)"
    sed -i "s#JENKINS_USER_PASSWORD#${JENKINS_USER_PASSWORD}#" ${OUTPUT}/sfcreds.yaml
    # Etherpad part
    ETHERPAD_SESSION_KEY=$(generate_random_pswd 10)
    sed -i "s#ETHERPAD_SESSION_KEY#${ETHERPAD_SESSION_KEY}#" ${OUTPUT}/sfcreds.yaml
    # Lodgeit/Paste part
    LODGEIT_SESSION_KEY=$(generate_random_pswd 10)
    sed -i "s#LODGEIT_SESSION_KEY#${LODGEIT_SESSION_KEY}#" ${OUTPUT}/sfcreds.yaml
}

function generate_keys {
    OUTPUT=${BUILD}/data
    mkdir -p ${OUTPUT}
    # Service key is used to allow puppetmaster root to
    # connect on other node as root
    ssh-keygen -N '' -f ${OUTPUT}/service_rsa
    [ -d /root/.ssh ] || mkdir /root/.ssh
    cp ${OUTPUT}/service_rsa /root/.ssh/id_rsa
    ssh-keygen -N '' -f ${OUTPUT}/jenkins_rsa
    ssh-keygen -N '' -f ${OUTPUT}/gerrit_service_rsa
    ssh-keygen -N '' -f ${OUTPUT}/gerrit_admin_rsa
    # generating keys for cauth
    openssl genrsa -out ${OUTPUT}/privkey.pem 1024
    openssl rsa -in ${OUTPUT}/privkey.pem -out ${OUTPUT}/pubkey.pem -pubout
}

function generate_apache_cert {
    OUTPUT=${BUILD}/data
    mkdir -p ${OUTPUT}
    # Generate self-signed Apache certificate
    cat > openssl.cnf << EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name

[ req_distinguished_name ]
commonName_default = ${SF_SUFFIX}

[ v3_req ]
subjectAltName=@alt_names

[alt_names]
DNS.1 = ${SF_SUFFIX}
DNS.2 = auth.${SF_SUFFIX}
EOF
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -subj "/C=FR/O=SoftwareFactory/CN=${SF_SUFFIX}" -keyout ${OUTPUT}/gateway.key -out ${OUTPUT}/gateway.crt -extensions v3_req -config openssl.cnf
}

function prepare_etc_puppet {
    DATA=${BUILD}/data
    HIERA=${BUILD}/hiera
    cp ${HIERA}/sfconfig.yaml /etc/puppetsf/hiera
    cp ${HIERA}/sfcreds.yaml /etc/puppetsf/hiera
    echo "sf_version: 1.0.3" > /etc/puppetsf/hiera/sf_version.yaml
    cp $DATA/service_rsa /etc/puppetsf/modules/ssh_keys/files/
    cp $DATA/service_rsa /root/.ssh/id_rsa
    cp $DATA/service_rsa.pub /root/.ssh/id_rsa.pub
    cp $DATA/jenkins_rsa /etc/puppetsf/modules/jenkins/files/
    cp $DATA/jenkins_rsa /etc/puppetsf/modules/zuul/files/
    cp $DATA/gerrit_admin_rsa /etc/puppetsf/modules/jenkins/files/
    cp $DATA/gerrit_service_rsa /etc/puppetsf/modules/gerrit/files/
    cp $DATA/gerrit_service_rsa.pub /etc/puppetsf/modules/gerrit/files/
    cp $DATA/gerrit_admin_rsa /etc/puppetsf/modules/managesf/files/
    cp $DATA/service_rsa /etc/puppetsf/modules/managesf/files/
    cp $DATA/gerrit_admin_rsa /etc/puppetsf/modules/jjb/files/
    cp $DATA/privkey.pem /etc/puppetsf/modules/cauth/files/
    cp $DATA/pubkey.pem /etc/puppetsf/modules/cauth/files/
    cp $DATA/gateway.key /etc/puppetsf/modules/commonservices-apache/files/
    cp $DATA/gateway.crt /etc/puppetsf/modules/commonservices-apache/files/
    cp $DATA/gateway.crt /etc/puppetsf/modules/https_cert/files/
    chown -R puppet:puppet /etc/puppetsf/
    chown -R puppet:puppet /var/lib/puppet
}
