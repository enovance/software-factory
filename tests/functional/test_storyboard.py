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

import json
import requests

import config
from utils import Base, skipIfServiceMissing

from pysflib.sfstoryboard import SFStoryboard


class TestStoryboard(Base):
    @skipIfServiceMissing('storyboard')
    def test_storyboard_hooks(self):
        hook_url = "%s/manage/hooks/" % config.GATEWAY_URL
        client = SFStoryboard(config.GATEWAY_URL + "/storyboard_api",
                              config.USERS[config.USER_4]['auth_cookie'])
        # Creates a story and task
        project = client.projects.get("config")
        story = client.stories.create(title="A new story")
        task = client.tasks.create(story_id=story.id, project_id=project.id,
                                   title="A new task")

        # Prepare a patchset created event
        change = {
            "change": "42",
            "project": "config",
            "commit_message": "Task: #%d\nStory: #%d" % (task.id, story.id)
        }

        # Call patchset_created hook
        cookies = dict(auth_pubtkt=config.USERS["admin"]['auth_cookie'])
        headers = dict(Authorization='Bearer will-be-set-by-apache')
        headers['Content-Type'] = 'application/json; charset=utf8'
        resp = requests.post("%s/patchset_created" % hook_url, headers=headers,
                             cookies=cookies, data=json.dumps(change))

        # Check task and story got updated
        self.assertEquals(resp.status_code, 200)
        self.assertEquals(resp.json()['msg'], "Success")
        task = client.tasks.get(task.id)
        self.assertEquals(task.status, "inprogress")
        self.assertIn("Fix proposed to",
                      client.stories.get(story.id).comments.list()[-1].content)

        # Call patchset_created hook
        resp = requests.post("%s/change_merged" % hook_url, headers=headers,
                             cookies=cookies, data=json.dumps(change))

        # Check task and story got updated
        self.assertEquals(resp.status_code, 200)
        self.assertEquals(resp.json()['msg'], "Success")
        task = client.tasks.get(task.id)
        self.assertEquals(task.status, "merged")
        self.assertIn("The following change on Gerrit has been merged",
                      client.stories.get(story.id).comments.list()[-1].content)

    @skipIfServiceMissing('storyboard')
    def test_storyboard_api_access(self):
        """ Test if storyboard is accessible on gateway hosts
        """
        urls = [config.GATEWAY_URL + "/storyboard_api/projects?limit=10",
                config.GATEWAY_URL + "/storyboard_api/stories?limit=10"]

        # Unauthenticated calls
        for url in urls:
            resp = requests.get(url)
            self.assertEqual(resp.status_code, 200)

        # Authenticated calls
        cookies = dict(auth_pubtkt=config.USERS[config.USER_4]['auth_cookie'])
        headers = dict(Authorization='Bearer will-be-set-by-apache')
        for url in urls:
            resp = requests.get(url, headers=headers, cookies=cookies)
            self.assertEqual(resp.status_code, 200)

        # Bad authenticated calls
        for url in urls:
            resp = requests.get(url, headers=headers)
            self.assertEqual(resp.history[0].status_code, 307)
            self.assertIn("auth/login", resp.url)

    @skipIfServiceMissing('storyboard')
    def test_storyboard_add_story(self):
        """ Test adding a story to storyboard """
        url = "%s/storyboard_api/stories" % config.GATEWAY_URL
        story = {
            "title": "A new hope",
            "description": "A long time ago in a galaxy far, far away...",
        }

        # Unauthenticated users can't add a story
        resp = requests.post(url, data=story)
        self.assertEqual(resp.status_code, 401)

        # Test story creation
        cookies = dict(auth_pubtkt=config.USERS[config.USER_4]['auth_cookie'])
        headers = dict(Authorization='Bearer will-be-set-by-apache')
        headers['Content-Type'] = 'application/json; charset=utf8'
        resp = requests.post(url, data=json.dumps(story),
                             headers=headers, cookies=cookies)
        self.assertEqual(resp.status_code, 200)
        story_id = resp.json()['id']

        # Check story retrieval
        url = "%s/storyboard_api/stories/%d" % (config.GATEWAY_URL, story_id)
        resp = requests.get(url)
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.json()['title'], "A new hope")

        # Check story deletion needs authenticated
        resp = requests.delete(url)
        self.assertEqual(resp.status_code, 401)
        # story deletion is admin only
        resp = requests.delete(url, headers=headers, cookies=cookies)
        self.assertEqual(resp.status_code, 403)

        cookies = dict(auth_pubtkt=config.USERS["admin"]['auth_cookie'])
        resp = requests.delete(url, headers=headers, cookies=cookies)
        self.assertEqual(resp.status_code, 204)
