#!/usr/bin/python

from sys import argv
import yaml
import os


def update_arch(filename):
    DEFAULT_ARCH = "/usr/local/share/sf-default-config/arch.yaml"
    dirty = False
    try:
        d = yaml.load(open(filename))
    except:
        print "%s: can't load" % filename
        raise

    # From 2.1.x to 2.2.x, inventory is missing from arch.yaml
    # replace former arch by default allinone arch
    if "inventory" not in d:
        dirty = True
        d = yaml.load(open(DEFAULT_ARCH).read())

    if dirty:
        os.rename(filename, "%s.orig" % filename)
        yaml.dump(d, open(filename, "w"), default_flow_style=False)


hiera_dir = argv[1]
update_arch("%s/arch.yaml" % hiera_dir)
