#!/srv/nodepool/bin/python

# Copyright (C) 2016 Red Hat
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

# This script is handy as an operator if a Software Factory instance
# that rely on Nodepool. Sometime (or after an upgrade) you may need
# to wipe the "node" table of the nodepool database to force Nodepool
# to restart from a clean state. Unfortunalty this will probably let
# some leftorvers on the Nodepool tenants. This script can be used
# to clean the VM(s) and releasing the floating ips of the slave nodes
# that are based on a nodepool snapshot. The option older_than can
# used if Nodepool has already restarted and you need to destroy only
# old VM(s). By default this script is noop.

### Two modes ###

# The mode walk read the list of images defined for each provider
# then find the belonging snapshots and finaly delete VMs that
# were spawned based on those snapshot.

# The mode regexp delete VMs on each providers if the VM's name
# match the regexp

import re
import sys
import yaml
import time
import argparse
from datetime import datetime
from datetime import timedelta
from novaclient import client as nclient
from neutronclient.v2_0 import client as neutron_client

parser = argparse.ArgumentParser(
    description='Delete slave VM(s) on Nodepool providers')
parser.add_argument(
    '-p', '--providers', type=str,
    nargs='?', default='_all_',
    help="Specify provider' names where you want to act (default: all)")
parser.add_argument(
    '-o', '--op',
    default=False,
    action='store_true',
    help='By default this command is no-op, set it --op to start actions')
parser.add_argument(
    '-c', '--config', type=str,
    default='/etc/nodepool/nodepool.yaml',
    help='Path to the nodepool.yaml file')
parser.add_argument(
    '-m', '--mode', type=str,
    default='walk',
    help='Mode can be (default:walk|regexp)')
parser.add_argument(
    '-r', '--regexp', type=str,
    default='.*',
    help='Match a regexp before deciding to delete '
         'if mode is regexp (default: ".*")')
parser.add_argument(
    '-t', '--older_than', type=int,
    default='0',
    help='Add a condition for the deletion. The slave will be deleted '
         'if it is older than * minute(s) (default: "0")')

NODEPOOL_SNAPSHOT_NAME = 'template-%s-[0-9]+'
args = parser.parse_args()
assert args.mode in ('walk', 'regexp')
reg = re.compile(args.regexp)

with open(args.config, "r") as fd:
    conf = yaml.load(fd)

with open("/etc/puppet/hiera/sf/sfconfig.yaml", "r") as fd:
    sfconf = yaml.load(fd)
    if sfconf['nodepool']['disabled'] is True:
        print "Nodepool is deactivated on your platform"
        sys.exit()


def find_images_from_conf(conf, provider):
    provider_conf = [p for p in conf['providers'] if
                     p['name'] == provider]
    try:
        provider_conf = provider_conf[0]
    except Exception:
        print "Unable to find %s in the config file" % provider
        return []

    provider_images = [i['name'] for i in provider_conf['images']]
    return provider_images


def find_nodepool_snapshot_ids(ilist, p_images_re):
    ret = []
    for image in ilist:
        found = False
        if 'image_type' not in image.to_dict()['metadata']:
            continue
        if image.to_dict()['metadata']['image_type'] == 'snapshot':
            for i_re in p_images_re:
                if i_re.match(image.to_dict()['name']):
                    ret.append(image.to_dict()['id'])
                    print "Found snapshot (%s) named : %s" % (
                        image.to_dict()['id'], image.to_dict()['name'])
                    found = True
                    break
        if not found:
            print "Not considered a Nodepool snapshot (%s)" % (
                image.to_dict()['name'])
    return ret


def release_floating_ip(floating_ip, neutron):
    l = neutron.list_floatingips()['floatingips']
    fid = [f['id'] for f in l if
           f['floating_ip_address'] == floating_ip][0]
    print "Releasing floating ip (%s)" % floating_ip
    neutron.delete_floatingip(fid)


def delete_server(args, server, neutron):
    if args.op is False:
        print "(Noop) Deleting - %s (%s)" % (
            server.name, server.id)
    else:
        print "Deleting - %s (%s)" % (server.name, server.id)
        floating_ip = [i['addr'] for i in
                       server.to_dict()['addresses'].values()[0]
                       if i['OS-EXT-IPS:type'] == 'floating'][0]
        server.delete()
        for i in xrange(30):
            cur_list = [n for n in nova.servers.list() if
                        n.name == server.name]
            if len(cur_list) == 1:
                print "Waiting for complete deletion ..."
                time.sleep(3)
            else:
                break
        release_floating_ip(floating_ip, neutron)

print "Start using the mode %s (noop: %s)" % (
    args.mode, not args.op)

for provider in conf['providers']:
    print
    if provider in args.providers.split(',') or \
       args.providers == '_all_':
        project_id = provider['project-name']
        username = provider['username']
        auth_url = provider['auth-url']
        password = provider['password']

        print "=== Acting on provider %s ===" % provider['name']
        if args.mode == "walk":
            p_images = find_images_from_conf(conf, provider['name'])
            p_images_re = []
            # Snapshots are named template-(image-name)-(timestamp)
            for img_name in p_images:
                p_images_re.append(
                    re.compile(NODEPOOL_SNAPSHOT_NAME % img_name))
            print "The following images are configured %s" % p_images

        nova = nclient.Client(2, username, password,
                              project_id, auth_url)

        # Needed to release the floating IP after deletion
        neutron = neutron_client.Client(username=username,
                                        password=password,
                                        tenant_name=project_id,
                                        auth_url=auth_url)

        slist = nova.servers.list()
        if args.mode == "walk":
            ilist = nova.images.list()
            print "--- Discovering nodepool snapshot ids ---"
            candidate_ids = find_nodepool_snapshot_ids(ilist, p_images_re)

        print "--- Walk through servers ---"
        for server in slist:
            created = datetime.strptime(server.to_dict()['created'],
                                        '%Y-%m-%dT%H:%M:%SZ')
            td = timedelta(minutes=args.older_than)
            if not (datetime.now() - created) > td:
                print "Skipping - %s (not older than " \
                      "%s minutes (created: %s))" % (
                          server.name, args.older_than, created)
                continue
            if args.mode == "walk":
                image_id = server.to_dict()['image']['id']
                if image_id in candidate_ids:
                    delete_server(args, server, neutron)
                else:
                    print "Skipping - %s (not based on nodepool snapshot)" % (
                        server.name)
            if args.mode == "regexp":
                if reg.match(server.name):
                    delete_server(args, server, neutron)
                else:
                    print "Skipping - %s (regexp not matched)" % server.name

print "Done."
