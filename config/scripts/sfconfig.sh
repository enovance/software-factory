#!/bin/bash
#
# copyright (c) 2014 enovance sas <licensing@enovance.com>
# copyright (c) 2016 Red Hat
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

# -----------------
# Functions
# -----------------
[ -z "${DEBUG}" ] || set -x
set -e

echo "[$(date)] Running sfconfig.sh"

# Defaults
DOMAIN=$(cat /etc/software-factory/sfconfig.yaml | grep "^fqdn:" | cut -d: -f2 | sed 's/ //g')
BUILD=/root/sf-bootstrap-data
HOME=/root

export PATH=/bin:/sbin:/usr/local/bin:/usr/local/sbin

function inject_keys {
    OUTPUT=/etc/software-factory/

    # Default authorized ssh keys on each node
    JENKINS_PUB="$(cat ${BUILD}/ssh_keys/jenkins_rsa.pub | cut -d' ' -f2)"
    SERVICE_PUB="$(cat ${BUILD}/ssh_keys/service_rsa.pub | cut -d' ' -f2)"
    sed -i "s#JENKINS_PUB_KEY#${JENKINS_PUB}#" ${OUTPUT}/sfcreds.yaml
    sed -i "s#SERVICE_PUB_KEY#${SERVICE_PUB}#" ${OUTPUT}/sfcreds.yaml

    # Gerrit part
    GERRIT_SERV_PUB="$(cat ${BUILD}/ssh_keys/gerrit_service_rsa.pub | cut -d' ' -f2)"
    GERRIT_ADMIN_PUB_KEY="$(cat ${BUILD}/ssh_keys/gerrit_admin_rsa.pub | cut -d' ' -f2)"
    sed -i "s#GERRIT_SERV_PUB_KEY#${GERRIT_SERV_PUB}#" ${OUTPUT}/sfcreds.yaml
    sed -i "s#GERRIT_ADMIN_PUB_KEY#${GERRIT_ADMIN_PUB_KEY}#" ${OUTPUT}/sfcreds.yaml

    for key in $(find ${BUILD}/ssh_keys -type f); do
        name=$(basename $key | sed "s/.pub/_pub/")
        hieraedit.py --yaml ${OUTPUT}/sfcreds.yaml -f $key $name
    done

    for cert in $(find ${BUILD}/certs -type f ); do
        name=$(basename $cert | sed 's/\.\([[:alpha:]]\{3\}\)/_\1/')
        hieraedit.py --yaml ${OUTPUT}/sfcreds.yaml -f $cert $name
    done

    hieraedit.py --yaml /etc/software-factory/sfcreds.yaml -f ${BUILD}/certs/gateway.crt gateway_chain

    chown -R root:root /etc/software-factory
    chmod -R 0750 /etc/software-factory
}

function generate_keys {
    # Re-entrant method, need to check if file exists first before creating
    OUTPUT=${BUILD}/ssh_keys
    [ -d "${OUTPUT}" ] || mkdir -p ${OUTPUT}

    # Service key is used to allow root access from managesf to other nodes
    [ -f ${OUTPUT}/service_rsa ]        || ssh-keygen -N '' -f ${OUTPUT}/service_rsa > /dev/null
    [ -f ${OUTPUT}/jenkins_rsa ]        || ssh-keygen -N '' -f ${OUTPUT}/jenkins_rsa > /dev/null
    [ -f ${OUTPUT}/gerrit_service_rsa ] || ssh-keygen -N '' -f ${OUTPUT}/gerrit_service_rsa > /dev/null
    [ -f ${OUTPUT}/gerrit_admin_rsa ]   || ssh-keygen -N '' -f ${OUTPUT}/gerrit_admin_rsa > /dev/null

    # generating keys for cauth
    OUTPUT=${BUILD}/certs
    [ -d "${OUTPUT}" ] || mkdir -p ${OUTPUT}

    [ -f ${OUTPUT}/privkey.pem ]        || openssl genrsa -out ${OUTPUT}/privkey.pem 1024
    [ -f ${OUTPUT}/pubkey.pem ]         || openssl rsa -in ${OUTPUT}/privkey.pem -out ${OUTPUT}/pubkey.pem -pubout

    [ -d "${HOME}/.ssh" ] || mkdir -m 0700 "${HOME}/.ssh"
    [ -f "${HOME}/.ssh/known_hosts" ] || touch "${HOME}/.ssh/known_hosts"

    # Default self-signed SSL certificate
    # If localCA doesn't exists, remove all ssl files
    [ -f ${OUTPUT}/localCA.pem ] || rm -f ${OUTPUT}/gateway.*

    # Gen CA
    OU=$(python -c "import random; print ''.join(random.choice('0123456789abcdef') for n in xrange(6))")
    [ -f ${OUTPUT}/localCA.pem ] || openssl req -nodes -days 3650 -new -x509 \
        -subj "/C=FR/O=SoftwareFactory/OU=${OU}" \
        -keyout ${OUTPUT}/localCAkey.pem         \
        -out ${OUTPUT}/localCA.pem

    # If FQDN changed, remove all ssl files
    [ -f ${OUTPUT}/gateway.cnf ] && [ "$(grep ' = ${DOMAIN}$' ${OUTPUT}/gateway.cnf))" == "" ] && \
        rm -f ${OUTPUT}/gateway.*

    # Gen conf
    [ -f ${OUTPUT}/gateway.cnf ] || {
        cat > ${OUTPUT}/gateway.cnf << EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name

[ req_distinguished_name ]
commonName_default = ${DOMAIN}

[ v3_req ]
subjectAltName=@alt_names

[alt_names]
DNS.1 = ${DOMAIN}
EOF
    }

    # Gen Key
    [ -f ${OUTPUT}/gateway.key ] || openssl genrsa -out ${OUTPUT}/gateway.key 2048
    # Gen Req
    [ -f ${OUTPUT}/gateway.req ] || openssl req -new -subj "/C=FR/O=SoftwareFactory/CN=${DOMAIN}" \
        -extensions v3_req -config ${OUTPUT}/gateway.cnf  \
        -key ${OUTPUT}/gateway.key              \
        -out ${OUTPUT}/gateway.req
    # Gen certificate
    [ -f ${OUTPUT}/localCA.srl ] || echo '00' > ${OUTPUT}/localCA.srl
    [ -f ${OUTPUT}/gateway.crt ] || openssl x509 -req -days 3650 \
        -extensions v3_req -extfile ${OUTPUT}/gateway.cnf \
        -CA ${OUTPUT}/localCA.pem               \
        -CAkey ${OUTPUT}/localCAkey.pem         \
        -CAserial ${OUTPUT}/localCA.srl         \
        -in ${OUTPUT}/gateway.req               \
        -out ${OUTPUT}/gateway.crt
    # Gen pem
    [ -f ${OUTPUT}/gateway.pem ] || cat ${OUTPUT}/gateway.key ${OUTPUT}/gateway.crt > ${OUTPUT}/gateway.pem
}

function wait_for_ssh {
    local host=$1
    while true; do
        KEY=$(ssh-keyscan -p 22 $host 2> /dev/null | grep ssh-rsa)
        if [ "$KEY" != ""  ]; then
            grep -q ${host} ${HOME}/.ssh/known_hosts || (echo $KEY >> $HOME/.ssh/known_hosts)
            echo "  -> $host:22 is up!"
            return 0
        fi
        let RETRIES=RETRIES+1
        [ "$RETRIES" == "40" ] && return 1
        echo "  [E] ssh-keyscan on $host_ip:22 failed, will retry in 1 seconds (attempt $RETRIES/40)"
        sleep 1
    done
}


# -----------------
# End of functions
# -----------------

echo "[sfconfig] Starting configuration"
generate_keys
inject_keys
/usr/local/bin/sf-update-hiera-config.py
/usr/local/bin/sf-ansible-generate-inventory.py \
    --domain ${DOMAIN} \
    --install_server_ip $(ip route get 8.8.8.8 | awk '{ print $7 }') \
    /etc/software-factory/arch.yaml
/usr/local/bin/sfconfig.py


# Configure ssh access to inventory
HOSTS=$(awk "/${DOMAIN}/ { print \$1 }" /etc/ansible/hosts | sort | uniq)
for host in $HOSTS; do
    wait_for_ssh $host
done

time ansible-playbook /etc/ansible/sf_setup.yml || {
    echo "[sfconfig] sf_setup playbook failed"
    exit 1
}

time ansible-playbook /etc/ansible/sf_initialize.yml || {
    echo "[sfconfig] sf_initialize playbook failed"
    exit 1
}

time ansible-playbook /etc/ansible/sf_postconf.yml || {
    echo "[sfconfig] sf_postconf playbook failed"
    exit 1
}

echo "${DOMAIN}: SUCCESS"
echo
echo "Access dashboard: https://${DOMAIN}"
echo "Login with admin user, get the admin password by running:"
echo "  awk '/admin_password/ {print \$2}' /etc/software-factory/sfconfig.yaml"
exit 0
