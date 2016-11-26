#!/bin/env python
# Manage global-requirements file

# Render freeze file:
# for venv in /var/www/cauth /var/www/managesf /srv/storyboard/; do
#   $venv/bin/pip freeze > $(basename $venv).freeze
# done
#
# Render global-requirements.txt:
# ./scripts/global-requirements.py requirements/* > global-requirements.txt
#

import sys
import os
from distutils.version import LooseVersion


MANUALLY_INSTALLED_PKGS = (
    "cauth", "managesf", "pysflib", "sfmanager",
    "storyboard", "python-storyboardclient"
)

get_pkg_name = lambda x: x.split('==')[0]
get_pkg_version = lambda x: LooseVersion(x.split('==')[1])

# *db* is a dict.items() of venv: packages list
data = {}
for venv in sys.argv[1:]:
    name = os.path.basename(venv.replace('.freeze', ''))
    data[name] = map(lambda x: x[:-1], open(venv).readlines())
db = data.items()
# *reqs* is a better version of db where shared packages are reduced
reqs = {}

# For each venv
for pos in xrange(len(db)):
    # For each package
    for pkg in db[pos][1]:
        pkg_name = get_pkg_name(pkg)

        # Remove known packages
        if pkg_name in MANUALLY_INSTALLED_PKGS:
            continue

        # *envs* is a list of environment containing a package
        envs = [db[pos][0]]
        # *pkgs* is a list of package version
        pkgs = set([pkg])

        # For each other venv
        for other_pos in xrange(pos + 1, len(db)):
            other_env = db[other_pos][0]
            # For each package of each other venv
            for other_pkg in db[other_pos][1]:

                # If package is shared, adds it to the lists
                if pkg_name == get_pkg_name(other_pkg):
                    envs.append(other_env)
                    pkgs.add(other_pkg)
                    break

            # If package is shared between venv, remove it from other venv
            if envs[-1] == other_env:
                db[other_pos][1].remove(other_pkg)

        # If multiple version of a packge exists, pick the most up-to-date
        if len(pkgs) > 1:
            best = list(pkgs)[0]
            for pkg in pkgs:
                if get_pkg_version(pkg) > get_pkg_version(best):
                    best = pkg
            pkgs.remove(best)
            print "# Picked %s, removed %s" % (best, " ".join(pkgs))
            pkgs = [best]
        reqs.setdefault("+".join(envs), set()).update(pkgs)


# Generate global-requirements
shared_venv = sorted(filter(lambda x: "+" in x, reqs.keys()))
uniq_venv = sorted(filter(lambda x: "+" not in x, reqs.keys()))
for venv in shared_venv + uniq_venv:
    print "\n# %s" % venv
    print "\n".join(sorted(list(reqs[venv]), key=lambda x: x.lower()))
