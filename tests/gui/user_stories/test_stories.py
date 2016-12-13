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


test_project = "DemoProject"


ENV = os.environ
ENV['LANG'] = 'en_US.UTF-8'
ENV['LC_CTYPE'] = ENV['LANG']


writer = codecs.getwriter('utf8')


class MockMovie:
    def __init__(self, *args, **kwargs):
        self.vars = {}

    def flush_vars(self):
        self.vars = {}


class ShellRecorder(BaseGuiTest):

    def make_reel(self, session_name):
        reel = subprocess.Popen('tmux new-session -d -s %s' % session_name,
                                stdout=writer(subprocess.PIPE),
                                stderr=subprocess.PIPE,
                                shell=True, env=ENV)
        return reel

    def start_movie(self, session_name, title, output_file):
        asciinema_cmd = 'asciinema rec -c "tmux attach -t %s"' % session_name
        asciinema_cmd += ' -y -t "%s"' % title
        asciinema_cmd += ' %s' % output_file
        movie = subprocess.Popen(asciinema_cmd,
                                 stdout=writer(subprocess.PIPE),
                                 stderr=subprocess.PIPE,
                                 shell=True,
                                 env=ENV)
        return movie

    def start_display(self, session_name):
        ENV.update({'DISPLAY': ':99', })
        xterm = 'xterm -u8 -e "tmux attach -t %s"'
        display = subprocess.Popen(xterm % session_name,
                                   stdout=writer(subprocess.PIPE),
                                   stderr=subprocess.PIPE,
                                   shell=True,
                                   env=ENV)
        return display

    def record(self, session_name, title, output_file):
        reel = self.make_reel(session_name)
        display = self.start_display(session_name)
        movie = self.start_movie(session_name, title, output_file)
        return reel, display, movie

    def stop_recording(self, session_name, reel, display, movie, output_file):
        spielbash.TmuxSendKeys(session_name, 'exit')
        spielbash.TmuxSendKeys(session_name, 'C-m')
        reel.communicate('exit')
        out, err = movie.communicate()
        print out
        print err
        display.communicate()
        with open(output_file, 'r') as m:
            j = json.load(m)
        if not j.get('width'):
            j['width'] = 80
        if not j.get('height'):
            j['height'] = 25
        with open(output_file, 'w') as m:
            json.dump(j, m)

    def play_scene(self, session_name, scene, mock_movie):
        spielbash.pause(0.4)
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


if __name__ == '__main__':
    from unittest import main
    main()
