#!/bin/env python
#
# Copyright (C) 2014 eNovance SAS <licensing@enovance.com>
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
import time
import stat
import tempfile

from utils import Base
from utils import set_private_key
from utils import ManageSfUtils
from utils import GerritGitUtils
from utils import Tool
from subprocess import Popen, PIPE, call

from pysflib.sfgerrit import GerritUtils


class TestProjectReplication(Base):
    """ Functional tests to verify the gerrit replication feature
    """
    def setUp(self):
        self.msu = ManageSfUtils(config.GATEWAY_URL)
        self.un = config.ADMIN_USER
        self.gu = GerritUtils(
            config.GATEWAY_URL,
            auth_cookie=config.USERS[self.un]['auth_cookie'])
        self.gu2 = GerritUtils(
            config.GATEWAY_URL,
            auth_cookie=config.USERS[config.USER_2]['auth_cookie'])
        self.k_idx = self.gu2.add_pubkey(config.USERS[config.USER_2]["pubkey"])
        priv_key_path = set_private_key(config.USERS[self.un]["privkey"])
        self.gitu_admin = GerritGitUtils(self.un,
                                         priv_key_path,
                                         config.USERS[self.un]['email'])

        # Configuration to access mirror repo present in managesf
        # This is the path where the project will be replicated
        self.managesf_repo_path = "ssh://%s@%s/home/gerrit/git/" % (
            config.GERRIT_USER, config.GATEWAY_HOST)

        # Prepare environment for git clone on mirror repo
        self.mt = Tool()
        self.mt_tempdir = tempfile.mkdtemp()
        # Copy the service private key in a flat file
        priv_key = file(config.GERRIT_SERVICE_PRIV_KEY_PATH, 'r').read()
        priv_key_path = os.path.join(self.mt_tempdir, 'user.priv')
        file(priv_key_path, 'w').write(priv_key)
        os.chmod(priv_key_path, stat.S_IREAD | stat.S_IWRITE)
        # Prepare the ssh wrapper script
        ssh_wrapper = "ssh -o StrictHostKeyChecking=no -i %s \"$@\"" % (
            priv_key_path)
        wrapper_path = os.path.join(self.mt_tempdir, 'ssh_wrapper.sh')
        file(wrapper_path, 'w').write(ssh_wrapper)
        os.chmod(wrapper_path, stat.S_IRWXU)
        # Set the wrapper as GIT_SSH env variable
        self.mt.env['GIT_SSH'] = wrapper_path

        self.config_clone_dir = None

        # Project we are going to configure the replication for
        self.pname = 'test/replication'

        # Remove artifacts of previous run if any
        self.delete_config_section(self.un, self.pname)
        self.delete_mirror_repo(self.pname)

    def tearDown(self):
        self.delete_config_section(self.un, self.pname)
        self.delete_mirror_repo(self.pname)
        self.msu.deleteProject(self.pname, self.un)
        self.gu2.del_pubkey(self.k_idx)

    # Can't use GerritGitUtils.clone as not sure when source uri repo
    # be ready.(i.e gerrit is taking time to create the mirror repo in managesf
    # node) So this clone may succeed or fail, we don't need 'git review -s'
    # and other review commands in clone method
    def clone(self, uri, target):
        self.assertTrue(uri.startswith('ssh://'))
        cmd = "git clone %s %s" % (uri, target)
        self.mt.exe(cmd, self.mt_tempdir)
        clone = os.path.join(self.mt_tempdir, target)
        return clone

    def create_project(self, name, user, options=None):
        self.msu.createProject(name, user, options)

    def ssh_run_cmd(self, sshkey_priv_path, user, host, subcmd):
        host = '%s@%s' % (user, host)
        sshcmd = ['ssh', '-o', 'LogLevel=ERROR',
                  '-o', 'StrictHostKeyChecking=no',
                  '-o', 'UserKnownHostsFile=/dev/null', '-i',
                  sshkey_priv_path, host]
        cmd = sshcmd + subcmd

        p = Popen(cmd, stdout=PIPE)
        return p.communicate()

    def delete_mirror_repo(self, name):
        sshkey_priv_path = config.GERRIT_SERVICE_PRIV_KEY_PATH
        user = 'gerrit'
        host = config.GATEWAY_HOST
        mirror_path = '/home/gerrit/git/%s.git' % name
        cmd = ['rm', '-rf', mirror_path]
        self.ssh_run_cmd(sshkey_priv_path, user, host, cmd)

    def create_config_section(self, url, project):
        url = "ssh://%s@%s:29418/config" % (self.un, config.GATEWAY_HOST)
        path = os.path.join(self.config_clone_dir, 'gerrit/replication.config')
        call("git config -f %s --remove-section remote.test_project" % path, shell=True)
        call("git config -f %s --add remote.test_project.projects %s" % (path, project), shell=True)
        call("git config -f %s --add remote.test_project.url %s" % (path, url), shell=True)
        self.gitu_admin.add_commit_for_all_new_additions(self.config_clone_dir)
        # The direct push will trigger the config-update job
        # as we commit through 29418
        self.gitu_admin.direct_push_branch(self.config_clone_dir, 'master')
        attempts = 0
        while attempts < 10:
            code = call("ssh %s ssh gerrit grep test_project /home/gerrit/site_path/etc/replication.config" %
                        config.GATEWAY_HOST, shell=True)
            if code == '0':
                return
            attempts += 1
            time.sleep(3)
        raise Exception('replication.config change never landed')
        
    def delete_config_section(self, user, project):
        url = "ssh://%s@%s:29418/config" % (self.un, config.GATEWAY_HOST)
        self.config_clone_dir = self.gitu_admin.clone(url, 'config', config_review=True)
        path = os.path.join(self.config_clone_dir, 'gerrit/replication.config')
        call("git config -f %s --remove-section remote.test_project" % path, shell=True)
        try:
            self.gitu_admin.add_commit_for_all_new_additions(self.config_clone_dir)
        except CalledProcessError:
            # Usualy nothing to commit here so pass
            return
        # The direct push will trigger the config-update job
        # as we commit through 29418
        self.gitu_admin.direct_push_branch(self.config_clone_dir, 'master')
        attempts = 0
        while attempts < 10:
            code = call("ssh %s ssh gerrit grep test_project /home/gerrit/site_path/etc/replication.config" % \
                        config.GATEWAY_HOST, shell=True)
            if code != '0':
                return
            attempts += 1
            time.sleep(3)
        raise Exception('replication.config change never landed')

    def mirror_clone_and_check_files(self, url, pname):
        retries = 0
        while True:
            clone = self.clone(url, pname)
            # clone may fail, as mirror repo is not yet ready(i.e gerrit not
            # yet replicated the project)
            if os.path.isdir(clone):
                if os.path.isfile(os.path.join(clone ,'testfile')):
                    shutil.rmtree(clone)
                    return True
            elif retries > 30:
                break
            else:
                time.sleep(3)
                retries += 1
        return False

    def test_replication(self):
        """ Test gerrit replication for review process
        """
        # Create the project
        self.create_project(self.pname, self.un)

        # Create new section for this project in replication.config
        self.create_config_section(self.un, self.pname)

        # Force gerrit to read its .ssh/config and known_hosts file
        call("ssh %s ssh gerrit systemctl restart gerrit" %
             config.GATEWAY_HOST, shell=True)
        call("ssh %s ssh gerrit /root/wait4gerrit.sh" %
             config.GATEWAY_HOST, shell=True)

        # Clone the project and submit it for review
        priv_key_path = set_private_key(config.USERS[self.un]["privkey"])
        gitu = GerritGitUtils(self.un,
                              priv_key_path,
                              config.USERS[self.un]['email'])
        url = "ssh://%s@%s:29418/%s" % (self.un, config.GATEWAY_HOST,
                                        self.pname)
        clone_dir = gitu.clone(url, self.pname)

        # Direct push in the repo
        gitu.add_commit_in_branch(clone_dir, 'master', "Test commit")
        gitu.direct_push_branch(clone_dir, 'master')

        # Verify if gerrit automatically triggered replication
        repo_url = self.managesf_repo_path + '%s.git' % self.pname
        self.assertTrue(self.mirror_clone_and_check_files(repo_url,
                                                          self.pname))
