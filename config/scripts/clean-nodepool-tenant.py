#!/usr/bin/env python

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

### Two modes ###

# The mode walk read the list of images defined for each provider
# then find the belonging snapshots and finaly delete VMs that
# were spawned based on those snapshot.

# The mode regexp delete VMs on each providers if the VM's name
# match the regexp

import re
import yaml
import time
import argparse
from novaclient import client as nclient

parser = argparse.ArgumentParser(
    description='Delete server on Nodepool providers')
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

#NODEPOOL_SNAPSHOT_NAME = 'template-%s-[0-9]+'
NODEPOOL_SNAPSHOT_NAME = 'snapshot-test'
args = parser.parse_args()
assert args.mode in ('walk', 'regexp')
reg = re.compile(args.regexp)

with open(args.config, "r") as fd:
    conf = yaml.load(fd)

def find_images_from_conf(conf, provider):
    provider_conf = [p for p in conf['providers'] if
                     p['name'] == provider]
    try:
        provider_conf = provider_conf[0]
    except Exception, e:
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

def delete_server(args, server):
    if args.op is False:
        print "(Noop) Deleting - %s (%s)" % (
            server.name, server.id)
    else:
        print "Deleting - %s (%s)" % (server.name, server.id)
        server.delete()
        for i in xrange(30):
            cur_list = [n for n in nova.servers.list() if
                        n.name == server.name]
            if len(cur_list) == 1:
                print "Waiting for complete deletion ..."
                time.sleep(3)
            else:
                break

print "Start using the mode %s (noop: %s)" % (
    args.mode, not args.op)

for provider in conf['providers']:
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
                    re.compile(NODEPOOL_SNAPSHOT_NAME)) # % img_name))
            print "The following images are configured %s" % p_images

        nova = nclient.Client(2, username, password,
                              project_id, auth_url)

        slist = nova.servers.list()
        if args.mode == "walk":
            ilist = nova.images.list()
            print "=== Discovering nodepool snapshot ids ==="
            candidate_ids = find_nodepool_snapshot_ids(ilist, p_images_re)

        print "=== Walk through servers ==="
        for server in slist:
            if args.mode == "walk":
                image_id = server.to_dict()['image']['id']
                if image_id in candidate_ids:
                    delete_server(args, server)
                else:
                    print "Skipping - %s (not based on a nodepool snapshot)" % (
                        server.name)
            if args.mode == "regexp":
                if reg.match(server.name):
                    delete_server(args, server)
                else:
                    print "Skipping - %s (regexp not matched)" % server.name

print "Done."
