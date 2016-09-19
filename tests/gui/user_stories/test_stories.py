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
# -*- coding: utf-8 -*-

import codecs
import json
import os
import subprocess
import time
from unittest import skipIf

try:
    import spielbash
except ImportError:
    spielbash = None
from selenium.common.exceptions import ElementNotVisibleException

from tests.gui.base import BaseGuiTest, caption, snapshot_if_failure
from tests.gui.base import loading_please_wait
from tests.functional import config
from tests.functional import utils


rdir = os.environ.get("SCREENSHOT_DIR", '/tmp/gui/')
test_project = "DemoProject"

writer = codecs.getwriter('utf8')


class MockMovie:
    def __init__(self, *args, **kwargs):
        self.vars = {}

    def flush_vars(self):
        self.vars = {}


class ShellRecorder(BaseGuiTest):

    def make_reel(self, session_name):
        if 'REQUESTS_CA_BUNDLE' in os.environ:
            subprocess.Popen(['tmux', 'setenv', '-g', 'REQUESTS_CA_BUNDLE',
                              os.environ['REQUESTS_CA_BUNDLE']]).wait()
        subprocess.Popen(['tmux', 'kill-session', '-t', session_name],
                         stderr=subprocess.PIPE).wait()
        subprocess.Popen(['tmux', 'new-session', '-d', '-s',
                          session_name]).wait()

    def start_movie(self, session_name, title, output_file):
        asciinema_cmd = [
            'asciinema', 'rec', '-c', "tmux attach -t %s" % session_name,
            '-y', '-t', title, output_file
        ]
        movie = subprocess.Popen(asciinema_cmd,
                                 stdout=writer(subprocess.PIPE),
                                 stderr=subprocess.PIPE)
        return movie

    def start_display(self, session_name):
        return subprocess.Popen(['xterm', '-u8', '-e',
                                 "tmux attach -t %s" % session_name])

    def record(self, session_name, title, output_file):
        self.make_reel(session_name)
        display = self.start_display(session_name)
        movie = self.start_movie(session_name, title, output_file)
        return display, movie

    def stop_recording(self, session_name, display, movie, output_file):
        spielbash.TmuxSendKeys(session_name, 'exit')
        spielbash.TmuxSendKeys(session_name, 'C-m')
        movie.wait()
        j = None
        with open(output_file, 'r') as m:
            j = json.load(m)
        if j is None:
            print "[ERROR] couldn't find asciinema json file"
            return
        if not j.get('width'):
            print "[WARNING] asciinema json file is missing width"
            j['width'] = 80
        if not j.get('height'):
            print "[WARNING] asciinema json file is missing height"
            j['height'] = 25
        with open(output_file, 'w') as m:
            json.dump(j, m)

    def play_scene(self, session_name, scene, mock_movie):
        time.sleep(0.4)
        s = None
        if 'action' in scene:
            s = spielbash.Scene(scene['name'], scene.get('action', ''),
                                session_name,
                                scene.get('keep', {}), mock_movie,
                                wait_for_execution=scene.get('wait', False))
        elif 'line' in scene:
            s = spielbash.Dialogue(scene['line'], session_name)
        elif 'press_key' in scene:
            s = spielbash.PressKey(scene['press_key'], session_name)
        elif 'pause' in scene:
            spielbash.pause(scene.get('pause', 1))
        else:
            raise Exception('Unknown scene type %r' % scene)
        if s:
            s.run()


class TestAdministratorTasks(ShellRecorder):

    def tearDown(self):
        sfmanager = utils.ManageSfUtils(config.GATEWAY_URL)
        sfmanager.deleteProject(test_project, config.ADMIN_USER)

    @snapshot_if_failure
    def test_create_project(self):
        """Create a project in the GUI"""
        self.driver.get(config.GATEWAY_URL)
        self.login_as(config.ADMIN_USER, config.ADMIN_PASSWORD)

        msg = ("Log in as administrator, "
               "then go to the dashboard from the top menu.")
        with caption(self.driver, msg) as driver:
            driver.get("%s/dashboard/" % config.GATEWAY_URL)

        #TODO (gp) Give the buttons an element id
        msg = "Click on the 'Create project' button."
        with loading_please_wait(self.driver) as driver:
            with caption(driver, msg) as _d:
                _d.find_element_by_css_selector("button.btn-primary").click()

        msg = ("Define your project here. "
               "Eventually specify an upstream repo to clone from.")
        with caption(self.driver, msg):
            self.highlight("#projectname").send_keys(test_project)
            self.highlight("#description").send_keys("Test Description")
            ele = self.highlight_button("Create project")
            ele.click()

        msg = "Now your project is ready."
        with loading_please_wait(self.driver) as driver:
            with caption(driver, msg):
                self.highlight_link(test_project).click()
        msg = "Thank you for watching !"
        with caption(self.driver, msg):
            self.highlight("body")

    @snapshot_if_failure
    def test_add_user_to_project(self):
        """Add a user to a project in the GUI"""
        sfmanager = utils.ManageSfUtils(config.GATEWAY_URL)
        sfmanager.createProject(test_project, config.ADMIN_USER)
        # must log in as user2 once before
        sfmanager.list_active_members(config.USER_2)

        self.driver.get(config.GATEWAY_URL)
        self.login_as(config.ADMIN_USER, config.ADMIN_PASSWORD)

        msg = ("Log in as administrator, "
               "then go to the dashboard from the top menu.")
        with caption(self.driver, msg) as driver:
            driver.get("%s/dashboard/" % config.GATEWAY_URL)

        msg = ("Click on the membership management button "
               "next to the project on which your user will work.")
        with caption(self.driver, msg):
            mgmt_btn_xpath = '//table/tbody/tr[td="%s"]'
            if utils.has_issue_tracker():
                mgmt_btn_xpath += '/td[4]/button[1]'
            else:
                mgmt_btn_xpath += '/td[3]/button[1]'
            self.highlight_by_xpath(mgmt_btn_xpath % test_project).click()

        msg = ("Look for the user to add in the search box.")
        with caption(self.driver, msg):
            user_search_xpath = (".//*[@id='modal_create_members']/div/div/"
                                 "form/div[1]/input")
            searchbox = self.highlight_by_xpath(user_search_xpath)
            self.assertNotEqual(searchbox, None)
            searchbox.send_keys(config.USER_2)

        msg = ("The user appears in the list below the search box.")
        with caption(self.driver, msg):
            user_found = (".//*[@id='modal_create_members']/div/div/form/"
                          "div[1]/table/tbody/tr[contains(.,'%s')]")
            u = self.highlight_by_xpath(user_found % config.USER_2)
            self.assertNotEqual(u, None)

        msg = ("Let's add the user as a Core Developer...")
        with caption(self.driver, msg):
            core_btn = (user_found + "/td[3]/input")
            b = self.highlight_by_xpath(core_btn % config.USER_2)
            self.assertNotEqual(b, None)
            b.click()

        msg = ("...And submit it.")
        with caption(self.driver, msg):
            ele = self.highlight_button("Submit")
            ele.click()

        msg = "Thank you for watching !"
        with caption(self.driver, msg):
            self.highlight("body")

    @skipIf(spielbash is None,
            'missing spielbash dependency')
    def test_create_project_from_CLI(self):
        sfm = "sfmanager --url %s --auth-server-url %s --auth %s:%s "
        sfm = sfm % (config.GATEWAY_URL, config.GATEWAY_URL,
                     config.ADMIN_USER, config.ADMIN_PASSWORD)
        sfm += "project create --name %s" % test_project
        scenes = [
            {'name': 'create a project from the CLI',
             'action': sfm,
             'keep': {},
             'wait': True},
            {'name': 'conclusion',
             'line': 'Now we can switch to the GUI...'},
        ]
        session_name = 'create_project_from_CLI'
        d, m = self.record(session_name,
                           'Create a project from the CLI',
                           '%s/create_project_from_CLI.json' % rdir)
        mock_movie = MockMovie()
        for scene in scenes:
            self.play_scene(session_name, scene, mock_movie)

        self.stop_recording(session_name, d, m,
                            '%s/create_project_from_CLI.json' % rdir)

        self.driver.get(config.GATEWAY_URL)
        self.login_as(config.ADMIN_USER, config.ADMIN_PASSWORD)

        self.driver.get("%s/dashboard/" % config.GATEWAY_URL)
        with loading_please_wait(self.driver):
            project = self.highlight_link(test_project)
            time.sleep(0.5)
            project.click()

    @skipIf(spielbash is None,
            'missing spielbash dependency')
    def test_add_user_to_project_from_CLI(self):
        # init project
        sfmanager = utils.ManageSfUtils(config.GATEWAY_URL)
        sfmanager.createProject(test_project, config.ADMIN_USER)
        # must log in as user2 once before
        sfmanager.list_active_members(config.USER_2)

        sfm = "sfmanager --url %s --auth-server-url %s --auth %s:%s "
        sfm = sfm % (config.GATEWAY_URL, config.GATEWAY_URL,
                     config.ADMIN_USER, config.ADMIN_PASSWORD)
        sfm += ("membership add --user %s --project %s "
                "--groups ptl-group core-group")
        sfm = sfm % (config.USERS[config.USER_2]['email'], test_project)
        scenes = [
            {'name': 'add user to project from the CLI',
             'action': sfm,
             'keep': {},
             'wait': True},
            {'name': 'conclusion',
             'line': 'Now we can switch to the GUI...'},
        ]
        session_name = 'add_user_to_project_from_CLI'
        d, m = self.record(session_name,
                           'add user to project from the CLI',
                           '%s/add_user_to_project_from_CLI.json' % rdir)
        mock_movie = MockMovie()
        for scene in scenes:
            self.play_scene(session_name, scene, mock_movie)

        self.stop_recording(session_name, d, m,
                            '%s/add_user_to_project_from_CLI.json' % rdir)

        self.driver.get(config.GATEWAY_URL)
        self.login_as(config.ADMIN_USER, config.ADMIN_PASSWORD)

        self.driver.get("%s/dashboard/" % config.GATEWAY_URL)
        with loading_please_wait(self.driver):
            mgmt_btn_xpath = '//table/tbody/tr[td="%s"]'
            if utils.has_issue_tracker():
                mgmt_btn_xpath += '/td[4]/button[1]'
            else:
                mgmt_btn_xpath += '/td[3]/button[1]'
            u = self.highlight_by_xpath(mgmt_btn_xpath % test_project)
            self.assertNotEqual(u, None)
            time.sleep(0.5)
            u.click()
            user_found = (".//*[@id='modal_create_members']/div/div/form/"
                          "div[1]/table/tbody/tr[contains(.,'%s')]")
            u = self.highlight_by_xpath(user_found % config.USER_2)
            self.assertNotEqual(u, None)
            time.sleep(1)

    @skipIf(spielbash is None,
            'missing spielbash dependency')
    def test_prepare_dev_environment(self):
        # init project
        sfmanager = utils.ManageSfUtils(config.GATEWAY_URL)
        sfmanager.createProject(test_project, config.ADMIN_USER)
        # must log in as user2 once before
        sfmanager.list_active_members(config.USER_2)
        mail = config.USERS[config.USER_2]['email']

        scenes = [
            {'name': 'intro',
             'line': ('Follow these steps to prepare a development '
                      'environment suitable for Software Factory.')},
            {'name': 'step1',
             'line': ('Step 1: install git review. On CentOS, use the '
                      'following command:')},
            {'name': 'git and git review',
             'action': 'sudo yum install -y git git-review'},
            {'name': 'pause',
             'pause': 5},
            {'name': 'step2',
             'line': ('Step 2: if needed, create a SSH keypair to be used '
                      'with gerrit for reviews.')},
            {'name': 'ssh keypair',
             'action': 'ssh-keygen -t rsa -b 4096 -C "%s"' % mail,
             'keep': {},
             'wait': False},
            {'name': 'pause',
             'pause': 5},
            {'name': 'save to user2_rsa',
             'action': '/tmp/user2_rsa'},
            {'name': 'confirm save',
             'press_key': 'ENTER'},
            {'name': 'no passphrase 1',
             'press_key': 'ENTER'},
            {'name': 'no passphrase 2',
             'press_key': 'ENTER'},
            {'name': 'get pub key',
             'line': 'Finally, copy the public key and add it to Gerrit:'},
            {'name': 'show pub key',
             'action': 'cat /tmp/user2_rsa.pub',
             'wait': False},
            {'name': 'pause',
             'pause': 2},
            {'name': 'end',
             'line': 'Now on to Gerrit...'}, ]

        session_name = 'prepare_dev_env'
        d, m = self.record(session_name,
                           'prepare the dev environment',
                           '%s/prepare_dev_env.json' % rdir)
        mock_movie = MockMovie()
        for scene in scenes:
            self.play_scene(session_name, scene, mock_movie)

        self.stop_recording(session_name, d, m,
                            '%s/prepare_dev_env.json' % rdir)

        with open('/tmp/user2_rsa.pub') as f:
            ssh_key = f.read()

        self.driver.get(config.GATEWAY_URL)
        self.login_as(config.USER_2, config.ADMIN_PASSWORD)
        self.driver.get("%s/r/" % config.GATEWAY_URL)

        self.driver.set_window_position(0, 0)
        self.driver.set_window_size(1900, 1000)

        msg = 'Click on the user settings page.'
        with caption(self.driver, msg):
            panel = self.highlight("div.menuBarUserNamePanel")
            time.sleep(1)
            panel.click()
            settings = self.highlight_link("Settings")
            time.sleep(1)
            settings.click()

        msg = 'Click on "SSH public keys" then "Add key".'
        xpath = (".//*[@id='gerrit_body']/div/div/div/div/table/tbody"
                 "/tr/td[2]/div/div/div[1]/button[2]")
        with caption(self.driver, msg) as d:
            self.highlight_link("SSH Public Keys").click()
            try:
                add_key = d.find_element_by_xpath(xpath)
                add_key.click()
            except ElementNotVisibleException:
                pass

        msg = 'Copy your public key here.'
        with caption(self.driver, msg) as d:
            txtarea = d.find_element_by_css_selector("textarea.gwt-TextArea")
            txtarea.send_keys(ssh_key)
            self.highlight_button('Add').click()

        msg = "You are now set up to work with Software Factory !"
        with caption(self.driver, msg):
            self.highlight("body")


if __name__ == '__main__':
    from unittest import main
    main()
