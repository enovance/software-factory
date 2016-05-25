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

from .base import BaseGuiTest
from . import config


class TestAdminstratorTasks(BaseGuiTest):

    def test_create_project(self):
        self.driver.get(config.GATEWAY_URL)
        self.login_as(config.ADMIN_USER, config.ADMIN_PASSWORD)
        self.driver.get("%s/dashboard/" % config.GATEWAY_URL)
        #TODO (gp) Give the buttons an element id
        btn = self.driver.find_element_by_css_selector("button.btn-primary")
