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

import urllib
import requests

import config
from utils import Base
from utils import skipIfServiceMissing


def get_cid_from_cookie(cookie):
    for val in urllib.unquote(cookie).split(';'):
        if val.startswith('cid='):
            return int(val.split('=')[1])
    raise RuntimeError("Couldn't find cid from cookie")


class TestStoryboard(Base):
    @skipIfServiceMissing('storyboard')
    def test_storyboard_api_access(self):
        """ Test if storyboard is accessible on gateway hosts
        """
        # Unauthenticated calls
        urls = [config.GATEWAY_URL + "/storyboard_api/projects?limit=10",
                config.GATEWAY_URL + "/storyboard_api/stories?limit=10"]

        for url in urls:
            resp = requests.get(url)
            self.assertEqual(resp.status_code, 200)

        cid = get_cid_from_cookie(config.USERS[config.USER_4]['auth_cookie'])
        # URL that requires login - shows login page
        url = config.GATEWAY_URL + "/storyboard_api/users/%d" % cid
        resp = requests.get(url)
        self.assertEqual(resp.status_code, 200)
        json = resp.json()

        for k, v in (("enable_login", True), ('is_superuser', False)):
            self.assertIn(k, json)
            self.assertEquals(json[k], v)
