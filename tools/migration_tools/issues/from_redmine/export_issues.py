#!/usr/bin/python
#
# Copyright (C) 2015 eNovance SAS <licensing@enovance.com>
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

import ConfigParser
import os.path
from redmine import Redmine
from redmine.managers import ResourceBadMethodError
import sys
import logging
from logging.handlers import RotatingFileHandler
from pysflib import sfauth
from pysflib import sfredmine
#from six.moves import urllib_parse


# TODO heavy refactoring - lots of things can be mutualized among migration tools
def get_logger(logfile):
    logger = logging.getLogger()
    logger.setLevel(logging.DEBUG)
    formatter = logging.Formatter('%(asctime)s :: %(levelname)s :: %(message)s')
    file_handler = RotatingFileHandler(logfile, 'a', 1000000, 1)
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(formatter)
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.WARN)
    logger.addHandler(file_handler)
    logger.addHandler(console_handler)
    return logger


logger = get_logger('migration.log')


def get_config_value(config_file, section, option):
    cp = ConfigParser.ConfigParser()
    cp.read(config_file)
    try:
        return cp.get(section, option)
    except:
        return None


def get_values(config_file='config.ini'):
    # check config file is present or not
    if not os.path.isfile(config_file):
        logger.error("config file is missing")
        sys.exit(1)  
    source_redmine = {'username': '', 'password': '',
                      'id': '', 'apikey': '',
                      'url': '', 'name': ''}
    for key in source_redmine.iterkeys():
        source_redmine[key] = get_config_value(config_file, 'SOURCE_REDMINE', key)
    dest_redmine = {'username': '', 'password': '',
                    'id': '', 'url': '', 'name': '',
                    'sf_domain': '', 'versions_to_skip': [],
                    'issues_to_skip': []}
    for key in dest_redmine.iterkeys():
        dest_redmine[key] = get_config_value(config_file, 'DEST_REDMINE', key)
    # if url ends with backslash, remove it before use.
    if source_redmine['url'].endswith('/'):
        source_redmine['url'] = source_redmine['url'][:-1]
    if dest_redmine['url'].endswith('/'):
        dest_redmine['url'] = dest_redmine['url'][:-1]
    versions_to_skip = get_config_value(config_file, 'SKIP', 'version_id')
    if versions_to_skip:
        dest_redmine['versions_to_skip'] = versions_to_skip.split(',')
    issues_to_skip = get_config_value(config_file, 'SKIP', 'issue_id')
    if issues_to_skip:
        dest_redmine['issues_to_skip'] = issues_to_skip.split(',')    
    return source_redmine, dest_redmine


def get_mapping(config_file, original_value):
    new_value = get_config_value(config_file, 'MAPPINGS', original_value)
    if not new_value:
        logger.debug('no mapping found for %s' % original_value)
        new_value = original_value
    else:
        logger.debug('%s mapped to %s' % (original_value, new_value))
    return new_value
    

class BaseRedmine(object):
    def __init__(self, username=None, password=None,
                 apikey=None, id=None, url=None, name=None):
        super(BaseRedmine, self).__init__()
        self.username = username
        self.password = password
        self.apikey = apikey
        self.id = id
        self.url = url
        self.name = name
        self._create_connector()

    def _create_connector(self):
        if self.apikey:
            self.redmine = Redmine(self.url, key=self.apikey,
                                   requests={'verify': False})
        else:
            self.redmine = Redmine(self.url, username=self.username,
                                   password=self.password,
                                   requests={'verify': False})


class BaseImporter(object):
    def __init__(self):
        super(BaseImporter, self).__init__()

    def fetch_trackers(self):
        raise NotImplementedError

    def fetch_wiki(self):
        raise NotImplementedError

    def fetch_issue_statuses(self):
        raise NotImplementedError

    def fetch_users(self):
        raise NotImplementedError

    def fetch_versions(self):
        raise NotImplementedError

    def fetch_issues(self):
        raise NotImplementedError


class RedmineImporter(BaseRedmine, BaseImporter):
    def __init__(self, username=None, password=None,
                 apikey=None, id=None, url=None, name=None):
        super(RedmineImporter, self).__init__(username, password, apikey, id, url, name)
        if not self.id:
            projects = self.redmine.project.all()
            id_candidates = [p.id for p in projects if p.name == self.name]
            try:
                self.id = id_candidates[0]
                logger.debug("Found project #%i" % self.id)
            except IndexError:
                logger.error("Project %s not found" % self.name)
                sys.exit(1)
        if not self.name:
            self.name = self.redmine.project.get(self.id)

    def fetch_issues(self):
        for issue in self.redmine.issue.filter(project_id=self.id,
                                               status_id='*'):
            logger.debug('Fetching issue %s: %s' % (issue.id, issue.subject))
            issue_data = {'source_id': issue.id,
                          'priority_id': 1 # set default priority to be safe
                         }
            if getattr(issue, 'subject', None):
                issue_data['subject'] = issue.subject
            if getattr(issue, 'description', None):
                issue_data['description'] = issue.description
            if getattr(issue, 'tracker', None):
                issue_data['tracker_id'] = issue.tracker.id
                issue_data['tracker_name'] = issue.tracker.name
            if getattr(issue, 'status', None):
                issue_data['status_id'] = issue.status.id
                issue_data['status_name'] = issue.status.name
            if getattr(issue, 'priority', None):
                issue_data['priority_id'] = issue.priority.id
                issue_data['priority_name'] = issue.priority.name
            if getattr(issue, 'done_ratio', None):
                issue_data['done_ratio'] = issue.done_ratio
            if getattr(issue, 'story_points', None):
                issue_data['story_points'] = issue.story_points
            if getattr(issue, 'fixed_version', None):
                issue_data['fixed_version_id'] = issue.fixed_version.id
                issue_data['version_name'] = issue.fixed_version.name
            if getattr(issue, 'assigned_to', None):
                issue_data['assigned_to_id'] = issue.assigned_to.id
                issue_data['assigned_to_login'] = self.redmine.user.get(issue.assigned_to.id).login               
            yield issue_data

    def fetch_versions(self):
        for version in self.redmine.version.filter(project_id=self.id):
            logger.debug("Fetching version %s: %s" % (version.id, version.name))
            version_data = {}
            version_data['source_id'] = version.id
            version_data['name'] = version.name
            if getattr(version, 'status', None):
                version_data['status'] = version.status
            yield version_data


def implemented_resource(resource):
    def decorator(f):
        def decorated(*args, **kwargs):
            try:
                f(*args, **kwargs)
            except NotImplementedError:
                logger.warning("Importing %s is not supported, skipping." % resource)
            except ResourceBadMethodError:
                logger.warning("Creating %s on target redmine is not supported, skipping." % resource) 
        return decorated
    return decorator           


class SFRedmineMigrator(BaseRedmine):
    def __init__(self, username=None, password=None,
                 apikey=None, id=None, url=None, name=None,
                 sf_domain=None, versions_to_skip=None, issues_to_skip=None):
        self.sf_domain = sf_domain
        super(SFRedmineMigrator, self).__init__(username, password,
                                                apikey, id, url, name)
        if not self.id:
            projects = self.redmine.project.all()
            logger.debug("Fetched %i projects" % len(projects))
            id_candidates = [p.id for p in projects if p.name == self.name]
            try:
                self.id = id_candidates[0]
                logger.debug("Found project #%i" % self.id)
            except IndexError:
                logger.warning("Project %s not found on %s, creating it" % (self.name, self.url))
                project = self.redmine.project.create(name=self.name,
                                                      identifier="-".join(self.name.lower().split(' ')))
                self.id = project.id
        if not self.name:
            self.name = self.redmine.project.get(self.id)
        self.versions_to_update = {}
        self.versions_to_skip = versions_to_skip
        if not self.versions_to_skip:
            self.versions_to_skip = []
        self.issues_to_skip = issues_to_skip
        if not self.issues_to_skip:
            self.issues_to_skip = []

    def _create_connector(self):
        c = sfauth.get_cookie(self.sf_domain, self.username, self.password)
        self.redmine = sfredmine.SFRedmine(self.url, auth_cookie=c)

    def migrate(self, importer):
        self.migrate_trackers(importer)
        self.migrate_wiki(importer)
        self.migrate_issue_statuses(importer)
        self.migrate_versions(importer)
        self.migrate_issues(importer)
        self.cleanup(importer)
    
    @implemented_resource("trackers")
    def migrate_trackers(self, importer):
        for tracker in importer.fetch_trackers():
            self.redmine.tracker.create(**tracker)

    @implemented_resource("wiki pages")
    def migrate_wiki(self, importer):
        for article in importer.fetch_wiki():
            self.redmine.wiki_page.create(**article)

    @implemented_resource("issue statuses")
    def migrate_issue_statuses(self, importer):
        for status in importer.fetch_issue_statuses():
            self.redmine.issue_status.create(**status)

    @implemented_resource("versions")
    def migrate_versions(self, importer):
        for version in importer.fetch_versions():
            if str(version['source_id']) not in self.versions_to_skip:
                del version['source_id']
                logger.debug("Migrating version '%s' ..." % version['name'])
                version['project_id'] = self.id
                real_version = None
                if version['status'] != 'open':
                    # open the version so we can add issues to it
                    real_version = version['status']
                    version['status'] = 'open'
                new_version = self.redmine.version.create(**version)
                if real_version:
                    self.versions_to_update[new_version.id] = real_version
            else:
                logger.debug("Skipping version #%s" % version['source_id'])

    def migrate_issues(self, importer):
        for issue in importer.fetch_issues():
            if str(issue['source_id']) in self.issues_to_skip:
                logger.debug("Skipping issue #%s" % issue['source_id'])
            else:
                logger.debug("Migrating issue #%s: %s ..." % (issue['source_id'],
                                                              issue['subject']))
                issue['project_id'] = self.id
                #check tracker
                if 'tracker_name' in issue:
                    mapped_tracker = get_mapping('config.ini', issue['tracker_name'])
                    tracker_candidates = [t.id for t in self.redmine.tracker.all()
                                          if t.name == mapped_tracker]
                    try:
                        issue['tracker_id'] = tracker_candidates[0]
                    except IndexError:
                        logger.debug("Tracker %s not found, leaving empty" % mapped_tracker)
                        del issue['tracker_id']
                #check issue status
                if 'status_name' in issue:
                    mapped_status = get_mapping('config.ini', issue['status_name'])
                    status_candidates = [t.id for t in self.redmine.issue_status.all()
                                         if t.name == mapped_status]
                    try:
                        issue['status_id'] = status_candidates[0]
                    except IndexError:
                        logger.debug("Status %s not found, leaving empty" % mapped_status)
                        del issue['status_id']
                #check version
                if 'version_name' in issue:
                    mapped_version = get_mapping('config.ini', issue['version_name'])
                    version_candidates = [t.id for t in self.redmine.version.filter(project_id=self.id)
                                          if t.name == mapped_version]
                    try:
                        issue['fixed_version_id'] = version_candidates[0]
                    except IndexError:
                        logger.debug("Version %s not found, leaving empty" % mapped_version)
                        del issue['fixed_version_id']
                #check user
                if 'assigned_to_login' in issue:
                    mapped_user = get_mapping('config.ini', issue['assigned_to_login'])
                    user_candidates = [t.id for t in self.redmine.user.filter(name=mapped_user)
                                       if t.login == mapped_user]
                    try:
                        logger.debug("User %s mapped to #%s" % (issue['assigned_to_login'],
                                                                user_candidates[0]))
                        issue['assigned_to_id'] = user_candidates[0]
                    except IndexError:
                        logger.debug("User %s not found, leaving empty" % mapped_user)
                        del issue['assigned_to_id']
                #check priority
                if 'priority_name' in issue:
                    mapped_priority = get_mapping('config.ini', issue['priority_name'])
                    priority_candidates = [t.id for t in self.redmine.enumeration.filter(resource='issue_priorities')
                                           if t.name == mapped_priority]
                    try:
                        issue['priority_id'] = priority_candidates[0]
                    except IndexError:
                        logger.debug("Priority %s not found, setting default priority 1" % mapped_version)
                        issue['priority_id'] = 1
                #clean unneeded values at this point
                for unneeded in ('tracker_name', 'status_name',
                                 'fixed_version_name', 'priority_name',
                                 'assigned_to_login', 'source_id'):
                    try:
                        del issue[unneeded]
                    except KeyError:
                        pass
                #create the issue finally!
                self.redmine.issue.create(**issue)

    def cleanup(self, *args, **kwargs):
        for version, status in self.versions_to_update.items():
            logger.debug("Re-setting correct status for version #%i" % version)
            self.redmine.version.update(version, status=status)


if __name__ == "__main__":
    source_redmine, dest_redmine = get_values()
    source = RedmineImporter(**source_redmine)
    target = SFRedmineMigrator(**dest_redmine)
    target.migrate(source)
