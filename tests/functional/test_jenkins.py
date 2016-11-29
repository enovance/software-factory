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

import random
import requests
import time

import config
from utils import Base
from utils import JenkinsUtils
from utils import get_cookie


def rand_suffix():
    return ''.join(random.sample('123456789abcdef', 3))


TEST_PARAMETERIZED_JOB="""<?xml version='1.0' encoding='UTF-8'?>
<project>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <scm class='jenkins.scm.NullSCM'/>
  <canRoam>true</canRoam>
  <disabled>false</disabled>
  <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
  <properties>
    <hudson.model.ParametersDefinitionProperty>
      <parameterDefinitions>
        <hudson.model.StringParameterDefinition>
          <name>timeout</name>
          <description>how long do we sleep</description>
          <defaultValue/>
        </hudson.model.StringParameterDefinition>
      </parameterDefinitions>
    </hudson.model.ParametersDefinitionProperty>
  </properties>
  <triggers class='vector'/>
  <concurrentBuild>false</concurrentBuild>
  <builders/>
    <hudson.tasks.Shell>
      <command>Echo "Hi, I am a lazy test."
set -x
sleep "$timeout"
set +x
echo "Done !"
      </command>
    </hudson.tasks.Shell>
  <publishers/>
  <buildWrappers/>
</project>"""


class TestJenkinsBasic(Base):
    """ Functional tests to validate config repo bootstrap
    """

    def setUp(self):
        super(TestJenkinsBasic, self).setUp()
        self.ju = JenkinsUtils()

    def test_config_jobs_exist(self):
        """ Test if jenkins config-update and config-check are created
        """
        url = '%s/job/config-check/' % self.ju.jenkins_url
        resp = self.ju.get(url)
        self.assertEquals(resp.status_code, 200)
        url = '%s/job/config-update/' % self.ju.jenkins_url
        resp = self.ju.get(url)
        self.assertEquals(resp.status_code, 200)


class TestJobsAPI(Base):
    def setUp(self):
        super(TestJobsAPI, self).setUp()
        cookie = get_cookie(config.ADMIN_USER, config.ADMIN_PASSWORD)
        self.cookie = {"auth_pubtkt": cookie}
        self.ju = JenkinsUtils()
        self.test_job = "test-sleep-" + rand_suffix()
        self.ju.create_job(self.test_job,
                           TEST_PARAMETERIZED_JOB)
        self.ju.run_job(self.test_job, {'timeout': '1'})
        self.ju.wait_till_job_completes(self.test_job, 1, 'lastBuild')
        self.base_url = config.GATEWAY_URL +"/manage/jobs/"

    def test_get_one(self):
        job = requests.get(self.base_url + "%s/id/1/" % self.test_job,
                           cookies=self.cookie).json
        self.assertTrue("jenkins" in job.keys(),
                        job)
        self.assertEqual(self.test_job,
                         job["jenkins"][0]["job_name"])

    def test_get_parameters(self):
        u = self.base_url + "%s/id/1/parameters" % self.test_job
        job = requests.get(u, cookies=self.cookie).json
        self.assertTrue("jenkins" in job.keys(),
                        job)
        self.assertEqual(self.test_job,
                         job["jenkins"][0]["job_name"])

    def test_get_logs(self):
        job = requests.get(self.base_url + "%s/id/1/logs" % self.test_job,
                           cookie=self.cookie).json
        self.assertTrue("jenkins" in job.keys(),
                        job)
        self.assertEqual(self.test_job,
                         job["jenkins"]["job_name"])
        logs_url = job["jenkins"]["logs_url"]
        r = requests.get(logs_url, cookies=self.cookie).text
        self.assertTrue("Hi, I am a lazy test." in r,
                        r)

    def test_run(self):
        last_build = self.ju.get_last_build_number(self.test_job,
                                                   'lastBuild')
        r = requests.post(self.base_url + self.test_job,
                          cookies=self.cookie,
                          data={'timeout': '3'}).json
        self.assertEqual(int(last_build) + 1,
                         int(r['jenkins']['job_id']),
                         r)

    def test_stop(self):
        last_build = self.ju.get_last_build_number(self.test_job,
                                                   'lastBuild')
        build = int(last_build) + 1
        self.ju.run_job(self.test_job, {'timeout': '60'})
        time.sleep(1)
        r = requests.delete(self.base_url + "%s/id/%s" % (self.test_job,
                                                          build),
                            cookies=self.cookie)
        self.assertTrue(int(r.status_code < 300), 
                        r.text)
