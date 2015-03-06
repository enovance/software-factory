var sfDashboard = angular.module('sfDashboard', []);

function mainController($scope, $http) {
    $scope.data = {};
    $scope.members= [];
    $scope.testRunning = Object();
    $scope.testLabels = [];

    function initProjects() {
        $scope.errors = false;
        $scope.loading = true;

        $http.get('/manage/project/')
            .success(function(data) {
                $scope.projects = data;
            })
            .error(function(data) {
                $scope.errors = data;
            }).finally(function () {
                $scope.loading = false;
            });
    };

    function initMembers() {
        $http.get('/manage/project/membership/')
            .success( function (data) {
                $scope.members = data;
            })
            .error( function (data) {
                $scope.errors = data;
            });
    };

    function initTests() {
        $http.get('/zuul/status.json')
            .success( function (data) {
                var projectName;
                var tests;
                var pipelines = data.pipelines;

                for ( var i = 0; i < pipelines.length; i++ ) {
		    // Create the list of test labels 
                    $scope.testLabels.push(pipelines[i].name);
                    tests = pipelines[i].change_queues;

                    for ( var j = 0; j < tests.length; j++  ) {
			// Create an entry only if there's a test running
                        if ( tests[j].heads.length > 0 ) {
			    projectName = tests[j].heads[0][0].project;
			    // Initialize test values of the project. 
                            if ( !(projectName in $scope.testRunning) ) {
                                $scope.testRunning[projectName] = [];
                                var k = pipelines.length;
                                while (k) $scope.testRunning[projectName][--k] = 0;
                            }

                            $scope.testRunning[projectName][i]++;
                        }
                    } 
                }
            })
            .error( function (data) {
                $scope.errors = data;
            });
    };

    function init() {
        initProjects();
        initMembers();
        initTests();
    };

    $scope.createProject = function() {
        $scope.errors = false;
        $scope.loading = true;

        $http.put('/manage/project/' + $scope.data.name , $scope.data)
            .success(function(data) {
                $scope.data = {};
                initProjects();
            })
            .error(function(data) {
            $scope.errors = data;
            }).finally(function () {
                $scope.loading = false;
            });
    };

    $scope.deleteProject = function(name) {
        if (window.confirm('Delete project ' + name + '?') ) {
            $scope.errors = false;
            $scope.loading = true;
            $http.delete('/manage/project/' + name)
                .success(function(data) {
                    $scope.data = {};
                    initProjects();
                })
                .error(function(data) {
                    $scope.errors = data;
                }).finally(function () {
                    $scope.loading = false;
                });
        }
    };

    $scope.membershipForm = function(projectName, projectObj) {
        $scope.selectedProjectName = projectName;
        $scope.selectedProject = projectObj;
        $scope.originalMembers = [];
        $scope.selectedMembers = [];
        var i = 0;
        var numMembers = $scope.members.length;

        var memberGroups = function ( member_id ) {
            var groups = projectObj["groups"];
            var memberGroups = {};
            var key;

            for ( key in groups ) {
                if ( groups.hasOwnProperty(key) ) {
                    memberGroups[key] = false;
                    for ( var k = 0; k < groups[key]["members"].length; k ++ ) {
                        if ( groups[key]["members"][k]['username'].match( member_id ) )
                            memberGroups[key] = true;
                    }
                }
            }
            return memberGroups;
        };

        for ( i = 0; i < numMembers; i++ ) {
            var member = $scope.members[i];
            $scope.originalMembers.push({name: member[2],
                                         email: member[1],
                                         groups: memberGroups(member[0])});
        }

        $scope.selectedMembers = JSON.parse(JSON.stringify($scope.originalMembers));
    };


    $scope.updateMembers = function() {
        if ( $scope.members.length < 1 ) {
            $scope.errors = "selected members list is empty";
            return;
        }
        var compareGroups = function (A, B) {
            var key;
            groups = {};
            for ( key in A ) {
                if (A[key] !== B[key]) {
                    groups[key] = B[key];
                }
            }
            return groups;
        };

        var x, key, groupName;
        for ( x = 0; x < $scope.originalMembers.length; x++ ) {
            var groups = compareGroups($scope.originalMembers[x].groups,
                                       $scope.selectedMembers[x].groups);
            var selectedMember = $scope.selectedMembers[x];
            var url = '/manage/project/membership/' +
                    $scope.selectedProjectName + '/' +
                    selectedMember.email + '/';

            for ( key in groups ) {
                groupName = key + '-group';
                if ( groups[key] ) {
                    $http.put(url, {"groups": [groupName]})
                        .success( function (data) {
                            initProjects();
                            initMembers();
                        })
                        .error( function (data) {
                            $scope.errors = data;
                        });
                }
                else {
                    $http.delete(url + groupName + '/')
                        .success( function (data) {
                            initProjects();
                            initMembers();
                        })
                        .error( function (data) {
                            $scope.errors = data;
                        });
                }
            }
        }
    };

    init();
}
