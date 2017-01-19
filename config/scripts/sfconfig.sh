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

set -e

logger "sfconfig.sh: started"
echo "[$(date)] Running sfconfig.sh"

/usr/local/bin/sfconfig.py                                              \
    --install_server_ip $(ip route get 8.8.8.8 | awk '{ print $7 }')    \
    --arch /etc/software-factory/arch.yaml

time ansible-playbook /etc/ansible/sf_initialize.yml

logger "sfconfig.sh: ended"
cat << EOF
${DOMAIN}: SUCCESS

Access dashboard: https://${DOMAIN}
Login with admin user, get the admin password by running:
  awk '/admin_password/ {print \$2}' /etc/software-factory/sfconfig.yaml

EOF
exit 0
