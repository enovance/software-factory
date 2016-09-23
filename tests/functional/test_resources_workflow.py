#!/bin/env python
#
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

import os
import config
import shutil

from utils import Base
from utils import set_private_key
from utils import GerritGitUtils
# from utils import JenkinsUtils

from utils import create_random_str

# from pysflib.sfgerrit import GerritUtils


class TestResourcesWorkflow(Base):

    def setUp(self):
        priv_key_path = set_private_key(
            config.USERS[config.ADMIN_USER]["privkey"])
        self.gitu_admin = GerritGitUtils(
            config.ADMIN_USER,
            priv_key_path,
            config.USERS[config.ADMIN_USER]['email'])

        self.dirs_to_delete = []

    def tearDown(self):
        for dirs in self.dirs_to_delete:
            shutil.rmtree(dirs)

    def clone_as_admin(self, pname):
        url = "ssh://%s@%s:29418/%s" % (config.ADMIN_USER,
                                        config.GATEWAY_HOST,
                                        pname)
        clone_dir = self.gitu_admin.clone(url, pname)
        if os.path.dirname(clone_dir) not in self.dirs_to_delete:
            self.dirs_to_delete.append(os.path.dirname(clone_dir))
        return clone_dir

    def commit_direct_push_as_admin(self, clone_dir, msg):
        # Stage, commit and direct push the additions on master
        self.gitu_admin.add_commit_for_all_new_additions(clone_dir, msg)
        self.gitu_admin.direct_push_branch(clone_dir, 'master')

    def test_basic(self):
        fpath = "%s.yaml" % create_random_str()
        config_clone_dir = self.clone_as_admin("config")
        namespace = create_random_str()
        name = create_random_str()
        resources = """resources:
  repos:
    %s:
      namespace: %s
      name: %s
      description: test for functional test
  projects: {}
  acls: {}
  groups: {}
"""
        resources = resources % (name, namespace, name)
        path = os.path.join(config_clone_dir, 'resources', fpath)
        file(path, 'w').write(resources)
        self.commit_direct_push_as_admin(
            config_clone_dir,
            "Add new resources for functional tests")
