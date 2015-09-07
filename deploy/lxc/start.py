#!/usr/bin/python

import os
import sys
import subprocess
import crypt, random, string

def gen_pass():
    return ''.join(random.choice(string.letters + string.digits) for _ in range(16))

def gen_hash(passwd):
    salt = '\$6\$' + gen_pass() + '\$'
    return crypt.crypt(passwd, salt)

def execute(argv):
    print "[+] Executing %s" % argv
    return subprocess.Popen(argv).wait()

def pread(argv):
    print "[+] Executing %s" % argv
    return subprocess.Popen(argv, stdout=subprocess.PIPE).communicate()[0]

def generate_sfconfig():
    return "\n".join([
        "domain: %s" % domain_name,
        "enforce_ssl: false",
        "admin_name: user1",
        "admin_mail: user1@tests.dom",
        "admin_password: userpass",
        "admin_password_hashed: %s" % gen_hash("userpass"),
        "admin_lastname: 'Demo user1'",
        "sso_cookie_timeout: 43200",
        "ldap_url:",
        "ldap_account_base:",
        "ldap_account_username_attribute:",
        "ldap_account_mail_attribute:",
        "ldap_account_surname_attribute:",
        "github_app_id:",
        "github_app_secret:",
        "github_allowed_organizations:",
        "jenkins_user_email: jenkins@tests.dom",
    ])

def prepare_role(name, ip, netmask="255.255.255.0", gateway="192.168.135.1"):
    if not os.path.isdir("/srv/sf-lxc"):
        os.mkdir("/srv/sf-lxc", 0755)
    if name == "install-server":
        role = "install-server-vm"
    else:
        role = "software-factory"
    root = "/srv/sf-lxc/%s" % name
    execute(["rsync", "-a", "--delete", "%s/%s/" % (base_path, role), "%s/" % root])

    print "[+] network"
    open("%s/etc/sysconfig/network-scripts/ifcfg-eth0" % root, "w").write(
        "DEVICE=eth0\n" +
        "ONBOOT=yes\n" +
        "BOOTPROTO=static\n" +
        "IPADDR=%s\n" % ip +
        "NETMASK=%s\n" % netmask +
        "GATEWAY=%s\n" % gateway
    )
    open("%s/etc/sysconfig/network" % root, "w").write(
        "NETWORKING=yes\n"+
        "HOSTNAME=%s.%s" % (name, domain_name)
    )
    open("%s/etc/hostname" % root, "w").write("%s.%s\n" % (name, domain_name))
    open("%s/etc/hosts" % root, "w").write("127.0.0.1 %s.%s %s localhost\n" % (name, domain_name, name))
    if not os.path.isdir("%s/root/.ssh" % root):
        os.mkdir("%s/root/.ssh" % root, 0755)

    print "[+] ssh access"
    open("%s/root/.ssh/authorized_keys" % root, "w").write(open("/home/centos/.ssh/id_rsa.pub").read())

    print "[+] cloud init"
    open("%s/etc/cloud/cloud.cfg.d/90_cloud.cfg" % root, "w").write(
        "dsmod: local\n\n" +
        "datasource_list: [ NoCloud ]\n"
    )
    nocloud_dir = "%s/var/lib/cloud/seed/nocloud" % root
    if not os.path.isdir(nocloud_dir):
        os.makedirs(nocloud_dir)
    open("%s/meta-data" % nocloud_dir, "w").write("local-hostname: %s" % name)
    cloud_init = open("%s.cloudinit" % name).read().replace("SF_SUFFIX", domain_name)
    open("%s/user-data" % nocloud_dir, "w").write(cloud_init)


def stop():
    execute(["virsh", "net-destroy", "sf-net"])
    for instance in pread(["virsh", "-c", "lxc:///", "list", "--all", "--name"]).split():
        execute(["virsh", "-c", "lxc:///", "destroy", instance])
        execute(["virsh", "-c", "lxc:///", "undefine", instance])

def start():
    prepare_role("install-server", "192.168.135.49")
    execute(["virsh", "-c", "lxc:///", "net-create", "libvirt-network.xml"])
    execute(["virsh", "-c", "lxc:///", "create", "libvirt-domain.xml"])
    execute(["virsh", "-c", "lxc:///", "list"])

try:
    base_path = sys.argv[1]
    if base_path == "stop":
        stop()
        exit(0)
    domain_name = sys.argv[2]
    sshpass = gen_pass()
    jenkins_user_pass = gen_pass()
    stop()
    start()
except IndexError:
    print "usage: %s base_path domain_name" % (base_path)
    exit(1)


