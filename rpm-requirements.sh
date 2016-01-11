#!/bin/bash
# SF environment requirements

echo "Install build requirement..."
sudo yum install -y patch curl wget git python-sphinx python-devel python-pip python-virtualenv mariadb-devel gcc libffi-devel openldap-devel openssl-devel python-sphinx
