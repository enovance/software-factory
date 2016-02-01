#!/bin/bash

set -x

bash rpm-requirements.sh

[ -d gerrit ] || {
    git clone https://gerrit.googlesource.com/gerrit
    (cd gerrit; git checkout -b sf_stable origin/stable-2.11)
}

[ -d buck ] || {
    git clone https://github.com/facebook/buck
    (cd buck; git checkout -b sf_stable $(cat ../gerrit/.buckversion); ant)
}

PLUGINS="avatars-gravatar replication reviewers-by-blame delete-project download-commands commit-message-length-validator reviewnotes singleusergroup"
for plugin in ${PLUGINS}; do
    [ -d $plugin ] || git clone https://gerrit.googlesource.com/plugins/$plugin
    cd $plugin
    # Make sure sf_stable points to origin/stable-2.11
    if [ "${plugin}" != "avatars-gravatar" ] && [ "$(git status | head -n 1)" != "# On branch sf_stable" ]; then
        git checkout -b sf_stable origin/stable-2.11
    fi
    git pull
    cd -
    # Make sure gerrit/plugins/$d symlink is correct
    if [ "$(readlink gerrit/plugins/$d)" != "$(pwd)/$plugin/" ]; then
        rm -Rf gerrit/plugins/$plugin
        ln -s $(pwd)/$plugin/ gerrit/plugins/
    fi
done

# Build gerrit and plugin
export PATH=${PATH}:$(pwd)/buck/bin
(
    cd gerrit;
    #git pull
    buck build gerrit
    buck build release
    for d in avatars-gravatar replication reviewers-by-blame delete-project download-commands; do
        buck build plugins/${d}
    done
)

# Install
mkdir -p build/home/gerrit/site_path/{lib,plugins}

# Copy buck build
cp ./gerrit/buck-out/gen/release.war build/home/gerrit/gerrit.war
for d in avatars-gravatar replication reviewers-by-blame delete-project download-commands; do
    cp gerrit/buck-out/gen/plugins/$d/$d.jar build/home/gerrit/site_path/plugins
done

# Fetch missing jar
[ -f build/home/gerrit/site_path/lib/bcprov-jdk15on-151.jar ] || {
    # Put last version 154 in place of one loaded by gerrit
    curl -L -o build/home/gerrit/site_path/lib/bcprov-jdk15on-151.jar https://www.bouncycastle.org/download/bcprov-jdk15on-154.jar
}

[ -f build/home/gerrit/site_path/lib/bcpkix-jdk15on-151.jar ] || {
    # Put last version 154 in place of one loaded by gerrit
    curl -L -o build/home/gerrit/site_path/lib/bcpkix-jdk15on-151.jar https://www.bouncycastle.org/download/bcpkix-jdk15on-154.jar
}

[ -f build/home/gerrit/site_path/lib/mysql-connector-java.jar ] || {
    # Put mysql-connector-java with the version number needed by gerrit
    cp /usr/share/java/mysql-connector-java.jar build/home/gerrit/site_path/lib/mysql-connector-java-5.1.21.jar
}

(cd build; sudo chown -R root:root home; tar czf gerrit-$(date '+%Y-%m-%d').tgz home)

echo "SFPKG build: build/gerrit-$(date '+%Y-%m-%d').tgz
