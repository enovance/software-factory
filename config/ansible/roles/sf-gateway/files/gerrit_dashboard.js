// @licstart  The following is the entire license notice for the
// JavaScript code in this page.
//
// Copyright 2016 Red Hat
//
// Licensed under the Apache License, Version 2.0 (the "License"); you may
// not use this file except in compliance with the License. You may obtain
// a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
// License for the specific language governing permissions and limitations
// under the License.
//
// @licend  The above is the entire license notice
// for the JavaScript code in this page.

angular.module('sfGerritDashboard', []).controller('mainController', function($scope, $http, $location, $window) {
    var name = $location.path().substring(1);

    $http.get("/static/dashboard_data.json")
        .then(function sucess(result) {
            if (name == "") {
                name = "default"
            }
            return result.data[name];
        })
        .then(function load_dashboard(dashboard) {
            if (dashboard == undefined) {
                $scope.Title = "Unknown dashboard!";
                return {data: []};
            }
            $scope.Sections = [];
            $scope.section_names = dashboard.tables;
            $scope.Title = dashboard.title;
            $scope.GerritDashboardLink = dashboard.gerrit_url;
            return $http.get(dashboard.gerrit_query)
        })
        .then(function display_dashboard(result) {
             for (pos = 0; pos < result.data.length; pos += 1) {
                if (result.data[pos].length == 0) {
                    continue;
                }
                for (change_pos = 0; change_pos < result.data[pos].length; change_pos += 1) {
                    // Remove miliseconds from updated date
                    result.data[pos][change_pos].updated = result.data[pos][change_pos].updated.substring(0, 19);
                }
                $scope.Sections.push({
                    title: $scope.section_names[pos],
                    results: result.data[pos],
                });
            }
        })
        .catch(function(result) {
            if (result.status == 400) {
                $window.location.href='/auth/login?back=/anchor/dash/'+name;
            } else {
                $scope.Title = "Unknown error";
            }
        })
});
