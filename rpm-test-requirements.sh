#!/bin/bash
# SF environment requirements

bash ./rpm-requirements.sh

PKGS=""
which ansible &> /dev/null    || PKGS="${PKGS} ansible"
which git-review &> /dev/null || PKGS="${PKGS} git-review"
which flake8 &> /dev/null     || PKGS="${PKGS} python-flake8"
which sfmanager &> /dev/null  || PKGS="${PKGS} python2-sfmanager"
if [ ! -z "${PKGS}" ]; then
    echo "(+) Installing test requirement..."
    sudo yum install -y $PKGS
fi
if [ "$(echo ${ZUUL_CHANGES} | grep python-sfmanager)" != "" ]; then
    sudo yum upgrade -y python2-sfmanager
fi
# Check if test-requirements are already installed
which tox &> /dev/null &&       \
which nosetests &> /dev/null && \
which bash8 &> /dev/null &&     \
test -d /usr/lib/python2.7/site-packages/nosetimer || {
    echo "(+) Installing test-requirements..."
    sudo pip install -r test-requirements.txt
}
