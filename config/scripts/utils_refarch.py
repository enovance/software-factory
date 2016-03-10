#!/usr/bin/python

import yaml
import os
import sys

from jinja2 import FileSystemLoader
from jinja2.environment import Environment


required_roles = (
    "install-server",
    "gateway",
    "auth",
    "mysql",
    "gerrit",
    "zuul",
    "jenkins",
)


def fail(msg):
    print >>sys.stdterr, msg
    exit(1)


def load_refarch(filename, domain="sftests.com"):
    arch = yaml.load(open(filename).read())
    # Update domain
    if domain:
        arch["domain"] = domain
    # Update each host and create roles dictionary
    arch["roles"] = {}
    arch["hosts_file"] = {}
    hostid = 10
    for host in arch["inventory"]:
        host["hostname"] = "%s.%s" % (host["name"], arch["domain"])
        aliases = set()
        for role in host["roles"]:
            arch["roles"].setdefault(role, []).append(host)
            if role == "redmine":
                aliases.add("api-redmine.%s" % arch['domain'])
            elif role == "gateway":
                aliases.add(arch['domain'])
            aliases.add("%s.%s" % (role, arch["domain"]))
            # Also add role name as a fqdn
            aliases.add(role)
        aliases.add(host["name"])
        arch["hosts_file"][host["ip"]] = [host["hostname"]] + list(aliases)
        # Set minimum requirement
        host.setdefault("cpu", "1")
        host.setdefault("mem", "4")
        host.setdefault("disk", "10")
        # Add id for network device name
        host["hostid"] = hostid
        hostid += 1

    # Check roles
    for requirement in required_roles:
        if requirement not in arch["roles"]:
            fail("%s role is missing" % requirement)
        if len(arch["roles"][requirement]) > 1:
            fail("Only one instance of %s is required" % requirement)

    # Adds gateway and install host to arch
    gateway_host = arch["roles"]["gateway"][0]
    install_host = arch["roles"]["install-server"][0]
    arch["gateway"] = gateway_host["hostname"]
    arch["gateway_ip"] = gateway_host["ip"]
    arch["install"] = install_host["hostname"]
    arch["install_ip"] = install_host["ip"]
    return arch


def render_jinja2_template(dest, template, data):
    with open(dest, "w") as out:
        loader = FileSystemLoader(os.path.dirname(template))
        env = Environment(trim_blocks=True, loader=loader)
        template = env.get_template(os.path.basename(template))
        out.write("%s\n" % template.render(data))
    if dest != "/dev/stdout":
        print "[+] Created %s" % dest
