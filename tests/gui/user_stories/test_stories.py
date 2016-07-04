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


from tests.gui.base import BaseGuiTest, caption, snapshot_if_failure
from tests.gui.base import loading_please_wait
from tests.functional import config
from tests.functional import utils


test_project = "Demo_Project"


class TestAdministratorTasks(BaseGuiTest):

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
            mgmt_btn_xpath = '//table/tbody/tr[td="%s"]/td[4]/button[1]'
            self.highlight_by_xpath(mgmt_btn_xpath % test_project).click()

        msg = ("Look for the user to add in the search box.")
        with caption(self.driver, msg):
            user_search_xpath = (".//*[@id='modal_create_members']/div/div/"
                                 "form/div[1]/input")
            searchbox = self.highlight_by_xpath(user_search_xpath)
            searchbox.send_keys(config.USER_2)

        msg = ("The user appears in the list below the search box.")
        with caption(self.driver, msg):
            user_found = (".//*[@id='modal_create_members']/div/div/form/"
                          "div[1]/table/tbody/tr[contains(.,'%s')]")
            self.highlight_by_xpath(user_found % config.USER_2)

        msg = ("Let's add the user as a Core Developer...")
        with caption(self.driver, msg):
            core_btn = (user_found + "/td[3]/input")
            self.highlight_by_xpath(core_btn % config.USER_2).click()

        msg = ("...And submit it.")
        with caption(self.driver, msg):
            ele = self.highlight_button("Submit")
            ele.click()

        msg = "Thank you for watching !"
        with caption(self.driver, msg):
            self.highlight("body")


if __name__ == '__main__':
    from unittest import main
    main()
