#!/bin/bash

. ./role_configrc

set -e

DEST_DIR="/var/lib/debootstrap/${SF_VER}"

[ -d "${DEST_DIR}" ] || mkdir ${DEST_DIR}

for role in install-server-vm softwarefactory; do
    SRC_FILE="${UPSTREAM}/${role}-${SF_VER}.edeploy"
    DST_TREE="${DEST_DIR}/${role}"
    [ -f "${DST_TREE}.done" ] && continue
    mkdir ${DST_TREE}
    echo "Extracting ${SRC_FILE} to ${DST_TREE}"
    tar -xzf ${SRC_FILE} -C ${DST_TREE}
    touch "${DST_TREE}.done"
done
echo "Done."
