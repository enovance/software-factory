#!/usr/bin/python

import os
import sys
import copy
import github3
import requests
import subprocess


def request(http_method, url, json=None):
    return requests.request(http_method, url=url, verify=True,
                            json=json)


if __name__ == '__main__':
    key = sys.argv[1]
    print "key: %s" % key
    org = 'softwarefactory-project'
    url = 'https://softwarefactory-project.io/manage/resources'
    resources = request(
        'get', url).json()['resources']['projects']['Software-Factory']

    anon = github3.GitHub()
    gorg = anon.organization(org)

    repos = [r.name for r in gorg.repositories()]
    print "%s repo inside the org %s" % (len(repos), org)

    to_create = []
    for sr in resources['source-repositories']:
        sr = os.path.basename(sr)
        if sr not in repos:
            to_create.append(sr)

    print "Repositories to create on the github org %s" % org
    for r_to_create in to_create:
        print r_to_create
    print "Amount %s" % len(to_create)

    if len(sys.argv) == 3 and sys.argv[2] == 'apply':
        basecmd = ['sfmanager', '--github-token', key,
                   'github', 'create-repo', '--org', org, '-n']
        for r_to_create in to_create:
            cmd = copy.copy(basecmd)
            cmd.append(r_to_create)
            print "Calling %s" % " ".join(cmd)
            subprocess.call(cmd)
