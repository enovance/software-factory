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

import functools
import os
import time
import unittest

from selenium import webdriver


def snapshot_if_failure(func):
    @functools.wraps(func)
    def f(self, *args, **kwargs):
        try:
            func(self, *args, **kwargs)
        except Exception as e:
            path = '/tmp/gui/'
            if not os.path.isdir(path):
                os.makedirs(path)
            screenshot = os.path.join(path, '%s.png' % func.__name__)
            self.driver.save_screenshot(screenshot)
            raise e
    return f


class BaseGuiTest(unittest.TestCase):
    def setUp(self):
        # close existing driver if any
        try:
            self.driver.quit()
        except AttributeError:
            pass
        self.driver = webdriver.Firefox()
        self.driver.maximize_window()

    def login_as(self, username, passwd):
        iframe = self.driver.find_element_by_tag_name("iframe")
        self.driver.switch_to.frame(iframe)
        self.driver.find_element_by_id("login-btn").click()
        self.driver.switch_to.default_content()
        self.driver.find_element_by_name("username").send_keys(username)
        self.driver.find_element_by_name("password").send_keys(passwd)
        self.driver.find_element_by_name("password").submit()

    def highlight(self, element_id):
        element = self.driver.find_element_by_id(element_id)
        style = element.get_attribute('style')
        hightlight = "%s background: yellow; border: 2px solid red;" % style
        js = "arguments[0].setAttribute('style', arguments[1]);"
        self.driver.execute_script(js, element, hightlight)
        time.sleep(.3)
        self.driver.execute_script(js, element, style)
