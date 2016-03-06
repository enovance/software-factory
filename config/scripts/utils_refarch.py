#!/usr/bin/python

import yaml
import os

from jinja2 import FileSystemLoader
from jinja2.environment import Environment


def load_refarch(filename, domain="sftests.com", ip_prefix=None):
    arch = yaml.load(open(filename).read())
    requirements = ["install-server", "gateway", "auth", "mysql", "gerrit",
                    "zuul", "jenkins"]
    # Update domain
    if domain:
        arch["domain"] = domain
    # Adds static ip suffix and hostname
    ip_suffix = 101
    for host in arch["inventory"]:
        host["domain"] = arch["domain"]
        host["hostname"] = "%s.%s" % (host["name"], arch["domain"])
        for role in host["roles"]:
            if role in requirements:
                requirements.remove(role)
        if "gateway" in host["roles"]:
            arch["gateway"] = host["hostname"]
            if ip_prefix:
                arch["gateway_ip"] = "%s.%s" % (ip_prefix, ip_suffix)
        if "install-server" in host["roles"]:
            arch["install-server"] = host["hostname"]
            if ip_prefix:
                arch["install-server_ip"] = "%s.%s" % (ip_prefix, ip_suffix)
        if ip_prefix:
            host["ip_prefix"] = ip_prefix
            host["ip_suffix"] = ip_suffix
            host["ip"] = "%s.%s" % (ip_prefix, ip_suffix)
            ip_suffix += 1
        host.setdefault("cpu", "1")
        host.setdefault("mem", "4")
        host.setdefault("disk", "10")
    if requirements:
        print "Error: refarch is missing required roles: %s" % requirements
        exit(1)
    return arch


def render_jinja2_template(dest, template, data):
    with open(dest, "w") as out:
        loader = FileSystemLoader(os.path.dirname(template))
        env = Environment(trim_blocks=True, loader=loader)
        template = env.get_template(os.path.basename(template))
        out.write(template.render(data))
    if dest != "/dev/stdout":
        print "[+] Created %s" % dest
