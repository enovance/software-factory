#!/bin/env python

import argparse
import os

from utils_refarch import load_refarch
from utils_refarch import render_jinja2_template


def render():
    arch = load_refarch(args.arch)
    arch["arch_raw"] = open(args.arch).read()
    for host in arch["inventory"]:
        # TODO: remove default m1.medium and find flavor automatically
        host["flavor"] = "m1.medium"
    render_jinja2_template(filename, "software-factory.hot.j2", arch)


def start():
    print "NotImplemented"
    # TODO: create keypair, get network id, upload image, start stack,
    #       wait for completion


def stop():
    print "NotImplemented"


parser = argparse.ArgumentParser()
parser.add_argument("--version")
parser.add_argument("--workspace", default="/var/lib/sf")
parser.add_argument("--domain", default="sftests.com")
parser.add_argument("--arch", default="../../config/refarch/allinone.yaml")
parser.add_argument("action", choices=[
    "start", "stop", "restart", "render"], default="render")
args = parser.parse_args()

try:
    arch = load_refarch(args.arch, args.domain)
    filename = "sf-%s.hot" % os.path.basename(args.arch).replace('.yaml', '')
except IOError:
    print "Invalid arch: %s" % args.arch
    exit(1)

if args.action == "start":
    start()
elif args.action == "stop":
    stop()
elif args.action == "restart":
    stop()
    start()
elif args.action == "render":
    render()
