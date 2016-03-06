#!/bin/env python

import argparse
import os
import subprocess
import yaml

from utils_refarch import load_refarch
from utils_refarch import render_jinja2_template


DEBUG = False


def execute(argv, silent=False):
    if not DEBUG and silent:
        stderr = subprocess.PIPE
    else:
        print "[deploy][debug] Executing %s" % argv
        stderr = None
    return subprocess.Popen(argv, stderr=stderr).wait()


def pread(argv, silent=False):
    if not DEBUG and silent:
        stderr = subprocess.PIPE
    else:
        print "[deploy][debug] Executing %s" % argv
        stderr = None
    return subprocess.Popen(argv,
                            stdout=subprocess.PIPE,
                            stderr=stderr).communicate()[0]


def virsh(argv, silent=False):
    execute(["virsh", "-c", "lxc:///"] + argv, silent)


def port_redirection(mode):
    if mode == "up":
        mode_arg = "-I"
        silent = False
    elif mode == "down":
        mode_arg = "-D"
        silent = True

    try:
        ext_interface = pread(["ip", "route", "get", "8.8.8.8"],
                              silent=silent).split()[4]
    except IndexError:
        raise RuntimeError("No default route available")

    execute(["iptables", mode_arg, "FORWARD", "-i", ext_interface,
             "-d", "%s.101" % args.ip_prefix, "-j", "ACCEPT"], silent=silent)
    for port in (80, 443, 8080, 29418, 45452, 64738):
        execute(["iptables", mode_arg, "PREROUTING", "-t", "nat",
                 "-i", ext_interface, "-p", "tcp", "--dport", str(port),
                 "-j", "DNAT", "--to-destination", "%s.101:%d" % (
                     args.ip_prefix, port)
                 ], silent=silent)
    for uport in (64738,):
        execute(["iptables", mode_arg, "PREROUTING", "-t", "nat",
                 "-i", ext_interface, "-p", "udp", "--dport", str(uport),
                 "-j", "DNAT", "--to-destination", "%s.101:%d" % (
                     args.ip_prefix, uport)
                 ], silent=silent)


def prepare_role(base_path, name, ip, netmask="255.255.255.0"):
    gateway = "%s.1" % args.ip_prefix
    print "[deploy] Prepare role %s (%s)" % (name, ip)
    if not os.path.isdir("/var/lib/lxc"):
        os.mkdir("/var/lib/lxc", 0755)
    if not os.path.isdir("/var/lib/lxc/%s" % name):
        os.mkdir("/var/lib/lxc/%s" % name, 0755)
    root = "/var/lib/lxc/%s/rootfs" % name
    if execute(["rsync", "-a", "--delete",
                "--exclude", "/var/lib/sf/roles/install/",
                "%s/softwarefactory/" % base_path,
                "%s/" % root]):
        print "Could not prepare %s with %s" % (name, base_path)
        exit(1)

    # network
    open("%s/etc/sysconfig/network-scripts/ifcfg-eth0" % root, "w").write(
        "DEVICE=eth0\n" +
        "ONBOOT=yes\n" +
        "BOOTPROTO=static\n" +
        "IPADDR=%s\n" % ip +
        "NETMASK=%s\n" % netmask +
        "GATEWAY=%s\n" % gateway
    )
    open("%s/etc/sysconfig/network" % root, "w").write(
        "NETWORKING=yes\n" +
        "HOSTNAME=%s.%s" % (name, args.domain)
    )
    open("%s/etc/hostname" % root, "w").write("%s\n" % (name))
    open("%s/etc/hosts" % root, "w").write("127.0.0.1 %s localhost\n" % name)
    if not os.path.isdir("%s/root/.ssh" % root):
        os.mkdir("%s/root/.ssh" % root, 0755)

    # ssh access
    ssh_dir = "%s/.ssh" % os.path.expanduser("~%s" % os.environ['SUDO_USER'])
    if not os.path.isdir(ssh_dir):
        os.mkdir(ssh_dir)
        os.chmod(ssh_dir, 0700)

    if not os.path.isfile("%s/id_rsa" % ssh_dir):
        execute(["ssh-keygen", "-f", "%s/id_rsa" % ssh_dir, "-N", ""])
        execute(["chown", os.environ['SUDO_USER'], "%s/id_rsa" % ssh_dir])
    open("%s/root/.ssh/authorized_keys" % root, "w").write(
        open("%s/id_rsa.pub" % ssh_dir).read()
    )

    # disable cloud-init
    for unit in ("cloud-init", "cloud-init-local", "cloud-config",
                 "cloud-final"):
        for p in ("etc/systemd/system/multi-user.target.wants",
                  "usr/lib/systemd/system"):
            s = "%s/%s/%s.service" % (root, p, unit)
            if os.path.exists(s):
                os.unlink(s)


def stop():
    print "[deploy] Stop"
    port_redirection("down")
    execute(["virsh", "net-destroy", args.domain], silent=True)
    for instance in pread([
        "virsh", "-c", "lxc:///", "list", "--all", "--name"
    ], silent=True).split():
        virsh(["destroy", instance], silent=True)
        virsh(["undefine", instance], silent=True)
    # Make sure no systemd-machinectl domain leaked
    for machine in pread(['machinectl', 'list'], silent=True).split('\n'):
        if 'libvirt-lxc' not in machine:
            continue
        execute(['machinectl', 'terminate', machine.split()[0]], silent=True)


def init(arch, base):
    print "[deploy] Init"
    hosts = {"localhost": {"ip": "127.0.0.1"}}
    for host in arch["inventory"]:
        # Generate hosts.yaml inventory
        host_def = {"ip": host["ip"], "host_aliases": [host["name"]]}
        if "gateway" in host["roles"]:
            host_def["host_aliases"].append(args.domain)
        if "redmine" in host["roles"]:
            host_def["host_aliases"].append("api-redmine")
            host_def["host_aliases"].append("api-redmine.%s" % args.domain)
        for role in host["roles"]:
            host_def["host_aliases"].append("%s.%s" % (role, args.domain))
            host_def["host_aliases"].append(role)
        hosts[host["hostname"]] = host_def
        # Prepare host rootfs
        prepare_role(base, host["hostname"], host["ip"])

    # "cloud-init": copy sfarch and hosts.yaml file
    root = "/var/lib/lxc/%s/rootfs" % arch["install-server"]
    open("%s/etc/puppet/hiera/sf/sfarch.yaml" % root, "w").write(
        open(args.arch).read())
    open("%s/etc/puppet/hiera/sf/hosts.yaml" % root, "w").write(
        yaml.dump({"hosts": hosts}, default_flow_style=False))

    # Generate libvirt domains
    for host in arch["inventory"]:
        render_jinja2_template("/var/lib/lxc/%s.xml" % host["hostname"],
                               "./libvirt-hosts.xml.j2",
                               host)
    render_jinja2_template("/var/lib/lxc/%s-network.xml" % args.domain,
                           "./libvirt-network.xml.j2", {
                               "domain": args.domain,
                               "ip_prefix": args.ip_prefix
                           })

    # Clean known_hosts
    execute(["sed", "-i",
             "/home/%s/.ssh/known_hosts" % os.environ["SUDO_USER"], "-e",
             "s/^%s\.[0-9].*$//" % args.ip_prefix])


def start(arch):
    print "[deploy] Start"
    virsh(["net-create", "/var/lib/lxc/%s-network.xml" % args.domain])
    for host in arch["inventory"]:
        virsh(["create", "/var/lib/lxc/%s.xml" % host["hostname"]])
    port_redirection("up")
    virsh(["list"])


def destroy():
    print "[deploy] Destroy"
    stop()
    # execute(["rm", "-Rf", "/var/lib/lxc/"])


if "SUDO_USER" not in os.environ:
    print "Only root can do that, use sudo!"
    exit(1)

parser = argparse.ArgumentParser()
parser.add_argument("--domain", default="sftests.com")
parser.add_argument("--version")
parser.add_argument("--workspace", default="/var/lib/sf")
parser.add_argument("--arch", default="../../config/refarch/allinone.yaml")
parser.add_argument("--ip_prefix", default="192.168.135")
parser.add_argument("action", choices=[
    "start", "stop", "restart", "init", "destroy"])
args = parser.parse_args()

try:
    arch = load_refarch(args.arch, args.domain, args.ip_prefix)
except IOError:
    print "Invalid arch: %s" % args.arch
    exit(1)
if args.action == "start":
    start(arch)
elif args.action == "stop":
    stop()
elif args.action == "restart":
    stop()
    start(arch)
elif args.action == "destroy":
    destroy()
elif args.action == "init":
    if args.version is None:
        # Extracts version from role_configrc... needs bash evaluation here
        args.version = pread([
            "bash", "-c", ". ../../role_configrc; echo $SF_VER"],
            silent=True).strip()
    init(arch, "%s/roles/install/%s" % (args.workspace, args.version))
    start(arch)
