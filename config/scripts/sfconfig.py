#!/usr/bin/python
# Licensed under the Apache License, Version 2.0
#
# Generate ansible group vars based on refarch and sfconfig.yaml

import argparse
import os
import yaml
import uuid


def append_legacy(allvars_file, args):
    """ Add bulk legacy vars to support smooth transition """
    allvars_file.write("###### Legacy content ######\n")
    allvars_file.write(open(args.sfconfig).read())
    allvars_file.write(open(args.sfcreds).read())
    allvars_file.write(open(args.arch).read())
    if os.path.isfile(args.extra):
        allvars_file.write(open(args.extra).read())


def yaml_load(filename):
    try:
        return yaml.safe_load(open(filename))
    except IOError:
        return {}


def generate_role_vars(allvars_file, args):
    """ This function 'glue' all roles and convert sfconfig.yaml """
    secrets = yaml_load("%s/secrets.yaml" % args.lib)
    arch = yaml_load(args.arch)
    sfconfig = yaml_load(args.sfconfig)

    # Generate all variable when the value is CHANGE_ME
    for role in arch["roles"]:
        role_vars = yaml_load("%s/roles/sf-%s/defaults/main.yml" % (
                              args.ansible_root, role))
        for key, value in role_vars.items():
            if str(value).strip().replace('"', '') == 'CHANGE_ME':
                if key not in secrets:
                    secrets[key] = str(uuid.uuid4())

    # Save secrets to new secrets file
    yaml.dump(secrets, open("%s/secrets.yaml" % args.lib, "w"))
    # And add them to the all.yaml file
    yaml.dump(secrets, allvars_file)

    # Generate dynamic role variable in the glue dictionary
    glue = {'mysql_databases': {}}

    def get_hostname(role):
        if len(arch["roles"][role]) != 1:
            raise RuntimeError("Role %s is defined on multi-host" % role)
        return arch["roles"][role][0]["hostname"]

    glue["gateway_url"] = "https://%s" % sfconfig["fqdn"]

    if "mysql" in arch["roles"]:
        glue["mysql_host"] = get_hostname("mysql")

    if "gerrit" in arch["roles"]:
        glue["gerrit_pub_url"] = "%s/r/" % glue["gateway_url"]
        glue["gerrit_email"] = "gerrit@%s" % sfconfig["fqdn"]
        glue["gerrit_mysql_host"] = glue["mysql_host"]
        glue["mysql_databases"]["gerrit"] = {
            'hosts': list(set(('localhost',
                               get_hostname("gerrit"),
                               get_hostname("managesf")))),
            'user': 'gerrit',
            'password': secrets['gerrit_mysql_password'],
        }

    yaml.dump(glue, allvars_file, default_flow_style=False)


def usage():
    p = argparse.ArgumentParser()
    p.add_argument("--ansible_root", default="/etc/ansible")
    p.add_argument("--arch", default="/etc/software-factory/_arch.yaml")
    p.add_argument("--sfconfig", default="/etc/software-factory/sfconfig.yaml")
    p.add_argument("--sfcreds", default="/etc/software-factory/sfcreds.yaml")
    p.add_argument("--extra", default="/etc/software-factory/custom-vars.yaml")
    p.add_argument("--lib", default="/var/lib/software-factory")
    return p.parse_args()


def main():
    args = usage()

    allyaml = "%s/group_vars/all.yaml" % args.ansible_root
    for dirname in ("%s/group_vars" % args.ansible_root, args.lib):
        if not os.path.isdir(dirname):
            os.mkdir(dirname, 0700)
    if os.path.islink(allyaml):
        os.unlink(allyaml)

    with open(allyaml, "w") as allvars_file:
        generate_role_vars(allvars_file, args)
        append_legacy(allvars_file, args)
    print("%s written!" % allyaml)


if __name__ == "__main__":
    main()
