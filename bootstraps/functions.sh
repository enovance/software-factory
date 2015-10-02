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

[ -z "${DEBUG}" ] && DISABLE_SETX=1 || set -x

# Defaults
DOMAIN=tests.dom
REFARCH=1node-allinone
IP_JENKINS=127.0.0.1
BUILD=/root/sf-bootstrap-data

function get_yaml {
    file=$1
    key=$2

    cat $file | grep "^${key}:" | sed "s/^${key}: //"
}

function generate_hosts_yaml {
    OUTPUT=${BUILD}/hiera
    local localip=$(ip route get 8.8.8.8 | awk '{ print $7 }')
    cat << EOF > ${OUTPUT}/hosts.yaml
hosts:
  localhost:              {ip: 127.0.0.1}
  mysql.${DOMAIN}:        {ip: ${localip}, host_aliases: [mysql]}
  jenkins.${DOMAIN}:      {ip: ${IP_JENKINS}, host_aliases: [jenkins]}
  redmine.${DOMAIN}:      {ip: ${localip}, host_aliases: [redmine]}
  api-redmine.${DOMAIN}:  {ip: ${localip}}
  gerrit.${DOMAIN}:       {ip: ${localip}, host_aliases: [gerrit]}
  managesf.${DOMAIN}:     {ip: ${localip}, host_aliases: [managesf, auth.${DOMAIN}, ${DOMAIN}]}
EOF
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

function generate_sfconfig_yaml {
    OUTPUT=${BUILD}/hiera
    # move config to bootstrap-data
    mv sfconfig.yaml ${OUTPUT}/
    # create a symlink to allow edits from bootstrap directory
    ln -s ${OUTPUT}/sfconfig.yaml .
}

function generate_creds_yaml {
    OUTPUT=${BUILD}/hiera
    mv sfcreds.yaml ${OUTPUT}/
    # MySQL password for services
    MYSQL_ROOT_SECRET=$(generate_random_pswd 32)
    REDMINE_MYSQL_SECRET=$(generate_random_pswd 32)
    GERRIT_MYSQL_SECRET=$(generate_random_pswd 32)
    NODEPOOL_MYSQL_SECRET=$(generate_random_pswd 32)
    ETHERPAD_MYSQL_SECRET=$(generate_random_pswd 32)
    LODGEIT_MYSQL_SECRET=$(generate_random_pswd 32)
    sed -i "s#MYSQL_ROOT_PWD#${MYSQL_ROOT_SECRET}#" ${OUTPUT}/sfcreds.yaml
    sed -i "s#REDMINE_SQL_PWD#${REDMINE_MYSQL_SECRET}#" ${OUTPUT}/sfcreds.yaml
    sed -i "s#GERRIT_SQL_PWD#${GERRIT_MYSQL_SECRET}#" ${OUTPUT}/sfcreds.yaml
    sed -i "s#NODEPOOL_SQL_PWD#${NODEPOOL_MYSQL_SECRET}#" ${OUTPUT}/sfcreds.yaml
    sed -i "s#ETHERPAD_SQL_PWD#${ETHERPAD_MYSQL_SECRET}#" ${OUTPUT}/sfcreds.yaml
    sed -i "s#LODGEIT_SQL_PWD#${LODGEIT_MYSQL_SECRET}#" ${OUTPUT}/sfcreds.yaml
    # Default authorized ssh keys on each node
    JENKINS_PUB="$(cat ${BUILD}/ssh_keys/jenkins_rsa.pub | cut -d' ' -f2)"
    SERVICE_PUB="$(cat ${BUILD}/ssh_keys/service_rsa.pub | cut -d' ' -f2)"
    sed -i "s#JENKINS_PUB_KEY#${JENKINS_PUB}#" ${OUTPUT}/sfcreds.yaml
    sed -i "s#SERVICE_PUB_KEY#${SERVICE_PUB}#" ${OUTPUT}/sfcreds.yaml
    # Redmine part
    REDMINE_API_KEY=$(generate_api_key)
    sed -i "s#REDMINE_API_KEY#${REDMINE_API_KEY}#" ${OUTPUT}/sfcreds.yaml
    # Gerrit part
    GERRIT_EMAIL_PK=$(generate_random_pswd 32)
    GERRIT_TOKEN_PK=$(generate_random_pswd 32)
    GERRIT_SERV_PUB="$(cat ${BUILD}/ssh_keys/gerrit_service_rsa.pub | cut -d' ' -f2)"
    GERRIT_ADMIN_PUB_KEY="$(cat ${BUILD}/ssh_keys/gerrit_admin_rsa.pub | cut -d' ' -f2)"
    sed -i "s#GERRIT_EMAIL_PK#${GERRIT_EMAIL_PK}#" ${OUTPUT}/sfcreds.yaml
    sed -i "s#GERRIT_TOKEN_PK#${GERRIT_TOKEN_PK}#" ${OUTPUT}/sfcreds.yaml
    sed -i "s#GERRIT_SERV_PUB_KEY#${GERRIT_SERV_PUB}#" ${OUTPUT}/sfcreds.yaml
    sed -i "s#GERRIT_ADMIN_PUB_KEY#${GERRIT_ADMIN_PUB_KEY}#" ${OUTPUT}/sfcreds.yaml
    # Jenkins part
    JENKINS_USER_PASSWORD="$(generate_random_pswd 32)"
    sed -i "s#JENKINS_USER_PASSWORD#${JENKINS_USER_PASSWORD}#" ${OUTPUT}/sfcreds.yaml
    # Etherpad part
    ETHERPAD_SESSION_KEY=$(generate_random_pswd 32)
    sed -i "s#ETHERPAD_SESSION_KEY#${ETHERPAD_SESSION_KEY}#" ${OUTPUT}/sfcreds.yaml
    # Lodgeit/Paste part
    LODGEIT_SESSION_KEY=$(generate_random_pswd 32)
    sed -i "s#LODGEIT_SESSION_KEY#${LODGEIT_SESSION_KEY}#" ${OUTPUT}/sfcreds.yaml

    ./hieraedit.py --yaml ${OUTPUT}/sfcreds.yaml -f ${BUILD}/ssh_keys/service_rsa service_rsa
    ./hieraedit.py --yaml ${OUTPUT}/sfcreds.yaml -f ${BUILD}/ssh_keys/jenkins_rsa jenkins_rsa
    ./hieraedit.py --yaml ${OUTPUT}/sfcreds.yaml -f ${BUILD}/ssh_keys/jenkins_rsa.pub jenkins_rsa_pub
    ./hieraedit.py --yaml ${OUTPUT}/sfcreds.yaml -f ${BUILD}/ssh_keys/gerrit_admin_rsa gerrit_admin_rsa
    ./hieraedit.py --yaml ${OUTPUT}/sfcreds.yaml -f ${BUILD}/ssh_keys/gerrit_service_rsa gerrit_service_rsa
    ./hieraedit.py --yaml ${OUTPUT}/sfcreds.yaml -f ${BUILD}/ssh_keys/gerrit_service_rsa.pub gerrit_service_rsa_pub
    ./hieraedit.py --yaml ${OUTPUT}/sfcreds.yaml -f ${BUILD}/certs/privkey.pem privkey_pem
    ./hieraedit.py --yaml ${OUTPUT}/sfcreds.yaml -f ${BUILD}/certs/pubkey.pem  pubkey_pem
    ./hieraedit.py --yaml ${OUTPUT}/sfcreds.yaml -f ${BUILD}/certs/gateway.key gateway_key
    ./hieraedit.py --yaml ${OUTPUT}/sfcreds.yaml -f ${BUILD}/certs/gateway.crt gateway_crt
}

function generate_keys {
    OUTPUT=${BUILD}/ssh_keys

    # Service key is used to allow root access from managesf to other nodes
    ssh-keygen -N '' -f ${OUTPUT}/service_rsa
    ssh-keygen -N '' -f ${OUTPUT}/jenkins_rsa
    ssh-keygen -N '' -f ${OUTPUT}/gerrit_service_rsa
    ssh-keygen -N '' -f ${OUTPUT}/gerrit_admin_rsa
    # generating keys for cauth
    OUTPUT=${BUILD}/certs
    openssl genrsa -out ${OUTPUT}/privkey.pem 1024
    openssl rsa -in ${OUTPUT}/privkey.pem -out ${OUTPUT}/pubkey.pem -pubout
}

function generate_apache_cert {
    OUTPUT=${BUILD}/certs
    # Generate self-signed Apache certificate
    cat > openssl.cnf << EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name

[ req_distinguished_name ]
commonName_default = ${DOMAIN}

[ v3_req ]
subjectAltName=@alt_names

[alt_names]
DNS.1 = ${DOMAIN}
DNS.2 = auth.${DOMAIN}
EOF
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -subj "/C=FR/O=SoftwareFactory/CN=${DOMAIN}" -keyout ${OUTPUT}/gateway.key -out ${OUTPUT}/gateway.crt -extensions v3_req -config openssl.cnf
}

function prepare_etc_puppet {
    OUTPUT=${BUILD}/hiera

    ./hieraedit.py --yaml ${OUTPUT}/sfconfig.yaml domain "${DOMAIN}"
    ./hieraedit.py --yaml ${OUTPUT}/sfconfig.yaml refarch "${REFARCH}"
    ./hieraedit.py --yaml ${OUTPUT}/sfconfig.yaml ip_jenkins "${IP_JENKINS}"
    cp ${OUTPUT}/sfconfig.yaml /etc/puppet/hiera/sf
    cp ${OUTPUT}/sfcreds.yaml /etc/puppet/hiera/sf
    cp ${OUTPUT}/hosts.yaml /etc/puppet/hiera/sf
    echo "sf_version: $(grep ^VERS= /var/lib/edeploy/conf | cut -d"=" -f2 | cut -d'-' -f2)" > /etc/puppet/hiera/sf/sf_version.yaml

    chown -R root:puppet /etc/puppet/hiera/sf
    chmod -R 0750 /etc/puppet/hiera/sf
}
