#!/bin/bash

PKGS=""
which gcc &> /dev/null || PKGS="${PKGS} gcc"
which ant &> /dev/null || PKGS="${PKGS} ant"
which git &> /dev/null || PKGS="${PKGS} git"
which zip &> /dev/null || PKGS="${PKGS} zip"
which curl &> /dev/null || PKGS="${PKGS} curl"
which java &> /dev/null || PKGS="${PKGS} java-1.7.0-openjdk-devel"
[ -f /usr/share/java/mysql-connector-java.jar ] || PKGS="${PKGS} mysql-connector-java"

[ -z "${PKGS}" ] || sudo yum install -y ${PKGS}
