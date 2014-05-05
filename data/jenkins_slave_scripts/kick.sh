#!/bin/bash

git clone http://sf-gerrit/r/config /root/config

# JJB
jenkins-jobs update /root/config/jobs
EXIT_CODE=$?

# Zuul
mkdir /etc/zuul # TODO: do this with puppet
cp /root/config/zuul/layout.yaml /etc/zuul/

# Clean
rm -Rf /root/config
exit ${EXIT_CODE}
