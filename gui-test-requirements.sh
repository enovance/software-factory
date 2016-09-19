#!/bin/bash
# SF gui test environment requirements

[ -f /usr/lib/selenium/selenium-server.jar ] || {
    echo "(+) Downloading selenium-server.jar"
    sudo mkdir -p /usr/lib/selenium/
    sudo curl -o /usr/lib/selenium/selenium-server.jar http://selenium-release.storage.googleapis.com/2.53/selenium-server-standalone-2.53.0.jar
}

[ -f /etc/yum.repos.d/epel.repo ] || sudo yum -y install epel-release

PKGS=""
which Xvfb &> /dev/null    || PKGS+=" Xvfb libXfont Xorg"
which java &> /dev/null    || PKGS+=" jre"
which firefox &> /dev/null || PKGS+=" firefox"
which tmux &> /dev/null    || PKGS+=" tmux"
which xterm &> /dev/null   || PKGS+=" xterm"
if [ ! -z "${PKGS}" ]; then
    echo "(+) Installing gui-test requirement..."
    sudo yum install -y $PKGS
fi

which ffmpeg &> /dev/null  || {
    sudo rpm --import http://li.nux.ro/download/nux/RPM-GPG-KEY-nux.ro
    sudo rpm -Uvh http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-1.el7.nux.noarch.rpm
    sudo yum install -y ffmpeg
}

which asciinema &> /dev/null || {
    sudo yum install -y asciinema
}


which spielbash &> /dev/null &&                         \
test -d /usr/lib/python2.7/site-packages/selenium &&    \
test -d /usr/lib/python2.7/site-packages/pyvirtualdisplay || {
    echo "(+) Installing test-requirements..."
    sudo pip install -r gui-test-requirements.txt
}
