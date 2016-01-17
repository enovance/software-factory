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

import requests
from utils import Base, logger
from config import GATEWAY_URL


class TestRedmineBasic(Base):
    """ Functional tests to validate redmine availability
    """

    def test_root_url_for_404(self):
        """ Test if redmine yield RoutingError
        """
        url = "%s/redmine/" % GATEWAY_URL
        for i in xrange(11):
            resp = requests.get(url)
            logger.debug("Calling %s" % url)
            self.assertNotEquals(resp.status_code, 404)
