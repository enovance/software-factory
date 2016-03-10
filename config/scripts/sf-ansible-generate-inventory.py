#!/usr/bin/python
# Licensed under the Apache License, Version 2.0
#
# Generate ansible inventory

import argparse
import os
import yaml

from utils_refarch import load_refarch
from utils_refarch import render_jinja2_template


def load_conf(name):
    return yaml.load(open("/etc/puppet/hiera/sf/%s.yaml" % name).read())


def install():
    if not os.path.isdir("/etc/ansible/group_vars"):
        os.mkdir("/etc/ansible/group_vars")
        os.chmod("/etc/ansible/group_vars", 0700)
    if not os.path.islink("/etc/ansible/group_vars/all.yaml"):
        os.symlink("/etc/puppet/hiera/sf/sfconfig.yaml",
                   "/etc/ansible/group_vars/all.yaml")


def get_puppet_modules(role):
    role_conf = "%s/roles/sf-%s/defaults/main.yml" % (ansible_root, role)
    modules = []
    if os.path.exists(role_conf):
        d = yaml.load(open(role_conf).read())
        if d and "puppet_modules" in d:
            if not isinstance(d["puppet_modules"], list):
                d["puppet_modules"] = [d["puppet_modules"]]
            modules = map(lambda x: "::%s" % x, d["puppet_modules"])
    return modules


def generate_inventory():
    arch = load_refarch(args.arch, args.domain)

    # Collect all roles and normalize inventory
    for host in arch["inventory"]:
        host["rolesname"] = map(lambda x: "sf-%s" % x, host["roles"])
        puppet_modules = set()
        for role in host["roles"]:
            for module in get_puppet_modules(role):
                puppet_modules.add(module)
        host["puppet_statement"] = "include %s" % (", ".join(puppet_modules))

    # Generate inventory
    if args.debug:
        print "Generate configuration for %s:" % args.arch
        print "\n#----8<----\n# Inventory"
    render_jinja2_template(args.inventory,
                           "%s/templates/inventory.j2" % ansible_root,
                           arch)

    # Generate main playbook
    if args.debug:
        print "\n#----8<----\n# Playbook"
    render_jinja2_template(args.playbook,
                           "%s/templates/sf_main.yml.j2" % ansible_root,
                           arch)

    if args.debug:
        print "\n#----8<----\n# Serverspec"
    render_jinja2_template(args.serverspec,
                           "%s/templates/serverspec.yml.j2" % ansible_root,
                           arch)

parser = argparse.ArgumentParser()
parser.add_argument("--domain", default="sftests.com")
parser.add_argument("--inventory", default="/etc/ansible/hosts")
parser.add_argument("--playbook", default="/etc/ansible/sf_main.yml")
parser.add_argument("--serverspec", default="/etc/serverspec/hosts.yaml")
parser.add_argument("--debug", action='store_const', const=True)
parser.add_argument("arch", help="refarch file")
args = parser.parse_args()

ansible_root = None
for path in ("/etc/ansible", "../ansible", "config/ansible"):
    if os.path.isdir("%s/roles/sf-base" % path):
        ansible_root = path
        break
if not ansible_root:
    print "Can't find sf-base role"
    exit(1)
sfconfig = "/etc/puppet/hiera/sf/sfconfig.yaml"
if not os.path.isfile(sfconfig):
    sfconfig = "%s/defaults/sfconfig.yaml" % os.path.dirname(ansible_root)

if args.debug:
    args.inventory = "/dev/stdout"
    args.playbook = "/dev/stdout"
    args.serverspec = "/dev/stdout"
else:
    install()

generate_inventory()
