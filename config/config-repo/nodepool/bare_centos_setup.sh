#!/bin/bash

. base.sh

# sync FS, otherwise there are 0-byte sized files from the yum/pip installations
sudo sync
sudo sync

echo "SUCCESS: bare-centos-7 done."
