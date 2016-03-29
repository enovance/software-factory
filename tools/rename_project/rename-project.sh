#!/bin/bash

set -ex

[ -z "$1" ] && {
    echo "Please provide old name as arg 1"
    exit 1
}
[ -z "$2" ] && {
    echo "Please provide new name as arg 2"
    exit 1
}

echo "update account_project_watches set project_name = \"$2\" where project_name = \"$1\";" | mysql gerrit
echo "update changes set dest_project_name = \"$2\", created_on = created_on where dest_project_name = \"$1\";" | mysql gerrit
echo "update projects set name = \"$2\", identifier = \"$2\" where name = \"$1\";" | mysql redmine
mkdir -p "/home/gerrit/site_path/git/$(dirname $2)"
[ -d "/home/gerrit/site_path/git/${1}.git" ] && mv "/home/gerrit/site_path/git/${1}.git" "/home/gerrit/site_path/git/${2}.git" || true
