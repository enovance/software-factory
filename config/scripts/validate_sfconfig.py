#!/usr/bin/python

from sys import argv
import yaml

try:
    d = yaml.load(open(argv[1]))
except:
    print "usage: %s sfconfig.yaml" % argv[0]
    raise

# Adds default values and validation here

# Use disabled key instead (2.0.1 -> 2.0.2)
if 'swift_logsexport_activated' in d['logs']:
    del d['logs']['swift_logsexport_activated']

yaml.dump(d, open(argv[1], "w"), default_flow_style=False)
exit(0)
