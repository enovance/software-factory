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

import re
import yaml
import time
import argparse
from novaclient import client

NODEPOOL_CONF = "/etc/nodepool/_nodepool.yaml"

parser = argparse.ArgumentParser(
    description='Delete server on Nodepool providers')
parser.add_argument(
    '-p', '--providers', type=str,
    nargs='?', default='_all_',
    help="Specify provider' names where you want to act (default: all)")
parser.add_argument(
    '-r', '--regexp', type=str,
    nargs='?', default='.*',
    help='Match a regexp before deciding to delete (default: ".*")')
parser.add_argument(
    '-o', '--op',
    default=False,
    action='store_true',
    help='By default this command is no-op, set it --op to start actions')

args = parser.parse_args()
reg = re.compile(args.regexp)

with open(NODEPOOL_CONF, "r") as fd:
    conf = yaml.load(fd)

for provider in conf['providers']:
    if provider in args.providers.split(',') or \
       args.providers == '_all_':
        project_id = provider['project-name']
        username = provider['username']
        auth_url = provider['auth-url']
        password = provider['password']
        nova = client.Client(2, username, password,
                             project_id, auth_url)

        print "=== Acting on provider %s ===" % provider['name']
        slist = nova.servers.list()
        for server in slist:
            if reg.match(server.name):
                if args.op is False:
                    print "(Noop) Deleting - %s (%s)" % (
                        server.name, server.id)
                else:
                    print "Deleting - %s (%s)" % (server.name, server.id)
                    server.delete()
                    for i in xrange(120):
                        cur_list = [n for n in nova.servers.list() if
                                    n.name == server.name]
                        if len(cur_list) == 1:
                            print "Waiting ..."
                            time.sleep(5)
                        else:
                            break
            else:
                print "Skipping - %s (regexp not matched)" % server.name

print "Done."
