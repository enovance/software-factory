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

import config
from .base import BaseGuiTest, snapshot_if_failure


class TestSoftwareFactoryDashboard(BaseGuiTest):
    def _internal_login(self, driver, user, password):
        u = driver.find_element_by_id("username")
        u.send_keys(user)
        p = driver.find_element_by_id("password")
        p.send_keys(password)
        p.submit()

    @snapshot_if_failure
    def test_login_page(self):
        driver = self.driver
        driver.get("%s/r/login" % config.GATEWAY_URL)
        self.assertTrue("Log in with Github" in driver.page_source)
        self.assertTrue("Internal Login" in driver.page_source)

    @snapshot_if_failure
    def test_admin_login(self):
        driver = self.driver
        driver.get("%s/r/login" % config.GATEWAY_URL)
        self.assertIn("SF", driver.title)
        self._internal_login(driver, config.USER_1, config.USER_1_PASSWORD)
        self.assertTrue("Project" in driver.page_source)
        self.assertTrue("Outgoing reviews" in driver.page_source)
        self.assertTrue("Administrator" in driver.page_source)

    @snapshot_if_failure
    def test_logout(self):
        driver = self.driver
        driver.get("%s/r/login" % config.GATEWAY_URL)
        self.assertIn("SF", driver.title)
        self._internal_login(driver, config.USER_1, config.USER_1_PASSWORD)
        driver.set_window_size(1280, 800)
        # switch to top menu iframe
        driver.switch_to.frame(driver.find_element_by_tag_name("iframe"))
        logout = driver.find_element_by_id("logout-btn")
        logout.click()
        driver.switch_to.default_content()
        self.assertTrue("Log in with Github" in driver.page_source)
        self.assertTrue("Internal Login" in driver.page_source)
        self.assertTrue(
            "successfully logged out" in driver.page_source)

    @snapshot_if_failure
    def test_topmenu_maximum_display(self):
        # Test for maximum screen size
        driver = self.driver
        driver.get(config.GATEWAY_URL)
        driver.maximize_window()
        driver.switch_to.frame(driver.find_element_by_tag_name("iframe"))
        assert driver.find_element_by_id("login-btn")
        driver.switch_to.default_content()
        self._internal_login(driver, config.USER_1, config.USER_1_PASSWORD)
        driver.switch_to.frame(driver.find_element_by_tag_name("iframe"))
        assert driver.find_element_by_id("logout-btn")

    @snapshot_if_failure
    def test_topmenu_minimum_display(self):
        # Test the minimum screen size (800px width)
        driver = self.driver
        driver.get(config.GATEWAY_URL)
        driver.set_window_size(800, 800)
        driver.switch_to.frame(driver.find_element_by_tag_name("iframe"))
        assert driver.find_element_by_id("login-btn")
        driver.switch_to.default_content()
        self._internal_login(driver, config.USER_1, config.USER_1_PASSWORD)
        driver.switch_to.frame(driver.find_element_by_tag_name("iframe"))
        assert driver.find_element_by_id("logout-btn")
