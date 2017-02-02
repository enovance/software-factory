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

angular.module('sfGerritDashboard', [], function($locationProvider) {
    $locationProvider.html5Mode(true);
}).controller('mainController', function($scope, $http, $location, $window) {
    var name = $location.path().substring(11);

    if (!name) {
        // Display list
        $http.get("/dashboards_data/data.json")
            .then(function success(result) {
                $scope.dashboardsList = result.data;
            });
        return;
    }
    $scope.dashboardsList = false;
    $scope.reviewsCount = 0;

    $scope.rowClass = function(change) {
        if (change.labels['Verified'].value > 0) {
            return "success";
        } else {
            return "warning";
        }
    };

    $http.get("/dashboards_data/data_"+name+".json")
        .then(function success(dashboard) {
            $scope.Sections = [];
            $scope.section_names = dashboard.data.tables;
            $scope.Title = dashboard.data.title;
            $scope.GerritDashboardLink = dashboard.data.gerrit_url;
            return $http.get(dashboard.data.gerrit_query)
        })
        .then(function display_dashboard(result) {
             for (pos = 0; pos < result.data.length; pos += 1) {
                if (result.data[pos].length == 0) {
                    continue;
                }
                for (change_pos = 0; change_pos < result.data[pos].length; change_pos += 1) {
                    // Remove miliseconds from updated date
                    result.data[pos][change_pos].updated = result.data[pos][change_pos].updated.substring(0, 19);
                    $scope.reviewsCount += 1;
                }
                $scope.Sections.push({
                    title: $scope.section_names[pos],
                    results: result.data[pos],
                });
            }
        })
        .catch(function(result) {
            if (result.status == 400) {
                $window.location.href='/auth/login?back=/dashboard/'+name;
            } else if (result.status == 404) {
                $scope.Title = "Dashboard not found";
            } else if (result.status == 0) {
                // GerritAccount cookie wasn't set
                $window.location.href='/dashboard/'+name;
            } else {
                $scope.Title = "Unknown error";
            }
        })
});
