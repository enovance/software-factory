#!/bin/bash
SRC=$(cd $(dirname $0); pwd)

. ${SRC}/third_party_tools

#---- Download tarballs to local Swift cache -----
# Swift env variables need to be set for this, for example:
# export ST_AUTH=http://127.0.0.1:8080/auth/v1.0
# export ST_USER=test:tester
# export ST_KEY=secret

for url in $URL_LIST; do
  filename=`echo "${url}" | sed 's/.*\///'`
  if [[ ${filename} == *.* ]] ; then  # Only for files
      curl -L -o /tmp/${filename} "${url}"
      swift upload cache /tmp/${filename} --object-name ${filename}
      rm /tmp/${filename}
  fi
done
