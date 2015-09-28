#!/bin/bash

set -e

echo "PREPARE SUBPROJECTS DIRECTORIES"

# If this script is run in our job runner the
# ZUUL_PROJECT will be set
[ -n "$ZUUL_PROJECT" ] && IN_ZUUL=1 || IN_ZUUL=0
[ $IN_ZUUL -eq 1 ] && echo "Triggered by Zuul ..."

PYSFLIB_REV=${PYSFLIB_PINNED_VERSION:-master}
CAUTH_REV=${CAUTH_PINNED_VERSION:-master}
MANAGESF_REV=${MANAGESF_PINNED_VERSION:-master}

# Default paths to find cloned dependencies
PYSFLIB_CLONED_PATH=${PYSFLIB_CLONED_PATH:="${PWD}/../deps/pysflib"}
CAUTH_CLONED_PATH=${CAUTH_CLONED_PATH:="${PWD}/../deps/cauth"}
MANAGESF_CLONED_PATH=${MANAGESF_CLONED_PATH:="${PWD}/../deps/managesf"}

# Default repo for deps if we need to fetch them
PYSFLIB_REPO=${PYSFLIB_REPO:="http://softwarefactory.enovance.com/r/pysflib"}
CAUTH_REPO=${CAUTH_REPO:="http://softwarefactory.enovance.com/r/cauth"}
MANAGESF_REPO=${MANAGESF_REPO:="http://softwarefactory.enovance.com/r/managesf"}

# Check if dependencies are present locally
# Our automatic job runner must have cloned the deps
[ -d $PYSFLIB_CLONED_PATH -a $IN_ZUUL -eq 1 ] && PYSFLIB_FETCH_MODE="local" || PYSFLIB_FETCH_MODE="remote"
[ -d $CAUTH_CLONED_PATH -a $IN_ZUUL -eq 1 ] && CAUTH_FETCH_MODE="local" || CAUTH_FETCH_MODE="remote"
[ -d $MANAGESF_CLONED_PATH -a $IN_ZUUL -eq 1 ] && MANAGESF_FETCH_MODE="local" || MANAGESF_FETCH_MODE="remote"

for PROJECT in "PYSFLIB" "CAUTH" "MANAGESF"; do
    eval PROJECT_FETCH_MODE=\$${PROJECT}_FETCH_MODE
    eval PROJECT_CLONED_PATH=\$${PROJECT}_CLONED_PATH
    eval PROJECT_REPO=\$${PROJECT}_REPO
    eval PROJECT_REV=\$${PROJECT}_REV
    eval PROJECT_KEEP=\$${PROJECT}_KEEP
    if [ "$PROJECT_FETCH_MODE" = "remote" ]; then
        if [ -z "$PROJECT_KEEP" ]; then
            echo "Fetch $PROJECT:$PROJECT_REV in $PROJECT_CLONED_PATH."
            [ -d $PROJECT_CLONED_PATH ] && rm -Rf $PROJECT_CLONED_PATH
            (git clone $PROJECT_REPO $PROJECT_CLONED_PATH &> /dev/null && cd $PROJECT_CLONED_PATH) || { echo "Fail to fetch $PROJECT" && exit 1; }
            (cd $PROJECT_CLONED_PATH && git checkout $PROJECT_REV) &> /dev/null || { echo "Fail to checkout rev:$PROJECT_REV" && exit 1; }
        else
            echo "(Forced) Use local source from $PROJECT_CLONED_PATH"
        fi
    else
        echo "Use local source from $PROJECT_CLONED_PATH"
        [ "$TAGGED_RELEASE" -eq 1 ] && {
            echo "Tagged release so use the pinned version"
            (cd $PROJECT_CLONED_PATH && git checkout $PROJECT_REV) &> /dev/null || { echo "Fail to checkout rev:$PROJECT_REV" && exit 1; }
        }
    fi
    (cd $PROJECT_CLONED_PATH && echo "-> $PROJECT head is: $(git log --pretty=oneline --abbrev-commit HEAD | head -1)")
done
