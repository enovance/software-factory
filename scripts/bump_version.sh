 #!/bin/bash
#
# How-to release a new version of SF:
#
#  1/ First edit role_configrc to set new and previous version strings. In this
#  example, 2.1.7 is the version to be released, 2.1.6 the last version, and
#  2.1.8 the current upstream work.
# VER=2.1.8
# SF_PREVIOUS_VER=C7.0-2.1.7
#     Please note: VER is the next version, and SF_PREVIOUS_VER the version to
#     release now in role_configrc. To avoid confusion, the following commands
#     will use RELEASE_VER=C7.0-2.1.7 and OLD_RELEASE_VER=C7.0-2.1.6
#  2/ Commit using 'TaggedRelease: ${RELEASE_VER}'
#  3/ Run this script to update references
#  4/ Check subproject history + sf history to update changelog
#  5/ Generate changelog with "reno report ." and copy the output to the CHANGELOG file
#     reno use a tag to compute the release version,
#  6/ update version acording 'TaggedRelease' number in the CHANGELOG file
#  7/ Commit --amend with all changes and new symlinks
#  8/ Wait for change to be merged (ask for review, recheck gate)
#  9/ Test new releases (either deploy or upgrade), in particular the changelog
# 10/ If published build is good, sign and re-publish the digest. You need the
#     passwordstore for this, set it up if not yet done:
#     sudo yum install -y pass
#     git clone ssh://cschwede@softwarefactory-project.io:29418/SF_password_store
#     source SF_password_store/.passrc
#     pass show sf/release@softwarefactory-project.io/passphrase
#     pass show sf/release@softwarefactory-project.io | gpg --import
# 11/ Download the actual digest
#     swift -A http://${SWIFTIP}:8080/auth/v1.0 -U sf:owner -K ${SWIFTPASS} download sf-images softwarefactory-${RELEASE_VER}.digest
# 12/ Sign the digest:
#     gpg -u release@softwarefactory-project.io --clearsign softwarefactory-${RELEASE_VER}.digest
# 13/ upload the signed digest to Swift:
#     mv softwarefactory-C7.0-${RELEASE_VER}.digest.asc softwarefactory-${RELEASE_VER}.digest
#     swift -A http://${SWIFTIP}:8080/auth/v1.0 -U sf:owner -K ${SWIFTPASS} upload sf-images softwarefactory-${RELEASE_VER}.digest
# 14/ Generate package diff
#     curl -O http://${SWIFTIP}:8080/v1/AUTH_sf/sf-images/softwarefactory-${OLD_RELEASE_VER}.description
#     curl -O http://${SWIFTIP}:8080/v1/AUTH_sf/sf-images/softwarefactory-${RELEASE_VER}.description
#     diff -y --suppress-common-lines softwarefactory-${OLD_RELEASE_VER}.description softwarefactory-${RELEASE_VER}.description
# 15/ Prepare mail, see previous announcement for template (re-use doug famous introduction from http://lists.openstack.org/pipermail/openstack-announce/)
# 16/ Tag: git tag -s -a -m "${RELEASE_VER}" ${RELEASE_VER} HEAD
# 17/ Submit tag: git push --tags gerrit
# 18/ Send announcement
#
. ./role_configrc

DEPS='/var/lib/sf/deps'

if [ "${TAGGED_RELEASE}" != "1" ]; then
    echo Run this script on a TaggedRelease: commit only
    exit 1
fi

# Read next version number directly to avoid CommitTag auto-change
NEW_VER="C7.0-$(grep ^VER role_configrc | cut -d= -f2)"

# Create new update path
echo "## Metadata path..."
echo "# Maintain old stable to current path"
for i in image/metadata/C7.0-2.0*/softwarefactory/C7.0-*; do
    echo git mv $i $(dirname $i)/${SF_VER}
done
echo "# Create new path"
echo mkdir -p image/metadata/${SF_VER}/softwarefactory
for i in image/metadata/C7.0-2.1*/softwarefactory/; do
    echo ln -s ../../metadata_2x/ ${i}/${NEW_VER}
done
echo ln -s ../../metadata_2x/ image/metadata/${SF_VER}/softwarefactory/${NEW_VER}
echo git add image/metadata

echo
echo "## Upgrade path..."
echo "# Maintain Upgrade path for stable"
for i in upgrade/C7.0-2.0*/*; do
    echo git mv $i $(dirname $i)/${SF_VER}
done
echo "# Create new path"
echo mkdir -p upgrade/${SF_VER}
for i in upgrade/C7.0-2.1*/; do
    echo ln -s ../upgrade_2x/ ${i}/${NEW_VER}
done
echo ln -s ../upgrade_2x/ upgrade/${SF_VER}/${NEW_VER}
echo git add upgrade
echo

# Change README
echo "## Documentation"
PREV_STABLE=$(grep "^The last stable" README.md | awk '{ print $6 }')
echo sed -i README.md -e "s/${SF_VER}/${NEW_VER}/g" -e "s/${PREV_STABLE}/${VER}/"
echo git add README.md
echo
echo "## Fetching subproject"
# Check subprojects origin/master
for i in pysflib managesf python-sfmanager cauth; do
    (cd ${DEPS}/$i; git fetch origin &> /dev/null)
    PINNED_VERSION=$(cat ${DEPS}/$i/.git/FETCH_HEAD | awk '{ print $1 }')
    VNAME="$(echo $i | tr '[:lower:]' '[:upper:]')_PINNED_VERSION"
    echo sed -i role_configrc -e \"s/${VNAME}=.*/${VNAME}=${PINNED_VERSION}/\"
done
echo git add role_configrc

echo git commit -a --amend
