#!/usr/bin/env python
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

import mock

from sfmigration.issues import csvfile
from sfmigration.tests.issues import common

# freely adapted from a googlecode CSV export
sample = (
    '"ID","Type","Status","Priority","Milestone","Owner","Summary",'
    '"Description", "AllLabels"\n'
    '"7","Enhancement","New","Medium","1.0.1","stan.marsh",'
    '"collect all chinpokomon","to fight the evil power",'
    '"Priority-Medium, Type-Enhancement"' )


mapping = {"source_id": "ID",
           "tracker_name": "Type",
           "status_name": "Status",
           "priority_name": "Priority",
           "version_name": "Milestone",
           "assigned_to_login": "Owner",
           "subject": "Summary",
           "description": "Description" }


sample_no_fieldnames = (
    """"7","Enhancement","New","Medium","1.0.1","stan.marsh","""
    """"collect all chinpokomon","to fight the evil power","""
    "\"Priority-Medium, Type-Enhancement\"")


fields = ['source_id', 'tracker_name', 'status_name', 'priority_name',
          'version_name', 'assigned_to_login', 'subject', 'description',
          'junk' ]


class _BaseTestCSVImporter(common.BaseTestImporter):

    @classmethod
    def setupClass(cls):
        cls.expected_issue = {
            'source_id': "7",
            'tracker_name': "Enhancement",
            'subject': "collect all chinpokomon",
            'description': "to fight the evil power",
            'status_name': "New",
            'priority_name': "Medium",
            'version_name': "1.0.1",
            'assigned_to_login': "stan.marsh", }
        cls.expected_version = {
            'source_id': None,
            'name': "1.0.1",
            'status': "open", }
        cls.mock_csv = ""

    def test_fetch_versions(self):
        with mock.patch('__builtin__.open',
                        mock.mock_open(read_data=self.mock_csv),
                        create=True) as m:
            self._test_result('versions')

    def test_fetch_issues(self):
        with mock.patch('__builtin__.open',
                        mock.mock_open(read_data=self.mock_csv),
                        create=True) as m:
            self._test_result('issues')


class TestCSVImporterWithFieldNames(_BaseTestCSVImporter):

    @classmethod
    def setupClass(cls):
        super(TestCSVImporterWithFieldNames, cls).setupClass()
        cls.mock_csv = sample
        with mock.patch('__builtin__.open',
                        mock.mock_open(read_data=cls.mock_csv),
                        create=True) as m:
            cls.importer = csvfile.CSVImporter(csv_file='pengin',
                                               fieldnames_mapping=mapping)


class TestCSVImporterWithoutFieldNames(_BaseTestCSVImporter):

    @classmethod
    def setupClass(cls):
        super(TestCSVImporterWithoutFieldNames, cls).setupClass()
        cls.mock_csv = sample_no_fieldnames
        with mock.patch('__builtin__.open',
                        mock.mock_open(read_data=cls.mock_csv),
                        create=True) as m:
            cls.importer = csvfile.CSVImporter(csv_file='pengin',
                                               fieldnames=fields)
