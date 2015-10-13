#!/bin/env python

from sys import argv
from os import path
import yaml
try:
    from pykwalify.core import Core
except ImportError:
    print "Could not find pykwalify, can't validate"
    exit(0)

DEFAULT_SPEC = "/usr/share/sfconfig-specs/sfconfig.yaml"

try:
    sfconfig_file = argv[1]
    if path.isfile(DEFAULT_SPEC):
        spec_file = DEFAULT_SPEC
    else:
        spec_file = argv[2]
except IndexError:
    print "usage: %s sfconfig.yaml [specs/sfconfig.yaml]" % (argv[0])
    exit(1)

## Update config
d = yaml.load(open(sfconfig_file))

## Change//add value here
# set correct default value
d['backup']['os_auth_url'] = ''
d['backup']['os_username'] = ''
d['backup']['os_password'] = ''
d['backup']['os_tenant_name'] = ''
d['authentication']['github']['github_app_secret'] = ''
d['authentication']['github']['github_allowed_organizations'] = ''
d['authentication']['github']['github_app_id'] = ''

yaml.dump(d, open(argv[1], "w"), default_flow_style=False)

## Validate config
c = Core(source_file=sfconfig_file, schema_files=[spec_file])
c.validate()
exit(0)
