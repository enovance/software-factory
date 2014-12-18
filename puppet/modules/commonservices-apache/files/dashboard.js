var sfDashboard = angular.module('sfDashboard', []);

function mainController($scope, $http) {
    $scope.data = {};
    $scope.members= [];

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

    function initReviews() {
        $http.get('/r/changes/?q=status:open')
            .success(function(data) {
                var reviews = {};
                for (key in data) {
                    var p = data[key].project;
                    if (reviews[p] == null) {
                        reviews[p] = 0;
                    }
                    reviews[p]++;
                }
                $scope.open_reviews = reviews;
            })
            .error(function(data) {
                $scope.errors = data;
            });
    };

    function initBugs() {
        $http.get('/redmine//issues.json?status_id=open')
            .success(function(data) {
                var bugs = {};
                for (var key in data['issues']) {
                    var p = data['issues'][key]["project"]["name"];
                    if (bugs[p] == null) {
                        bugs[p] = {};
                        bugs[p]['id'] = data['issues'][key]["project"]["id"];
                        bugs[p]['count'] = 0;
                    }
                    bugs[p]['count']++;
                }
                $scope.open_bugs = bugs;
            })
            .error(function(data) {
                $scope.errors = data;
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

    function init() {
        initProjects();
        initReviews();
        initBugs();
        initMembers();
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

    $scope.selectMembers = function(selectedGroup) {

        if ( $scope.selectedMembers.length < 1 ) {
            return;
        }

        $scope.errors = false;
        $scope.loading = true;

        var addMemberToGroup = function (item, index, members) {
            var url = '/manage/project/membership/' + $scope.selectedProject + '/' + item.id + '/';

            $http.put(url, {groups: [selectedGroup]} )
                .success( function(data) {
                    selectedGroup.members.push(item);
                })
                .error( function(data) {
                    selectedGroup.members.push(item);
                    $scope.errors = data;
                });
        };

        $scope.selectedMembers.map(addMemberToGroup);
        $scope.loading = false;
	$scope.selectedMembers = [];
    };

    $scope.deselectMembers = function(selectedGroup) {

	if (selectedGroup.members.length < 1){
	    return;
	}

        $scope.errors = false;
        $scope.loading = true;

        var removeMemberFromGroup = function (item, index, members) {

            var url = '/manage/project/membership/' + $scope.selectedProject
                    + '/' + item.id + '/' + selectedGroup.name;

            $http.delete(url)
                .success( function(data) {
                    selectedGroup.members.splice(index, 1);
                    console.log(data);
                })
                .error( function(data) {
                    $scope.errors(data);
                });
        };

        selectedGroup.members.map(removeMemberFromGroup);
        $scope.loading = false;
	$scope.selectedMembers = [];
    };

    $scope.membershipForm = function(projectName, projectObj) {
        $scope.selectedProjectName = projectName;
        $scope.selectedProject = projectObj;
        $scope.originalMembers = {};
        var i = 0;
        var numMembers = $scope.members.length;

        var memberGroups = function ( member_id ) {
            var groups = projectObj["groups"];
            var memberGroups = [];
            var key;

            for ( key in groups ) {
                if ( groups.hasOwnProperty(key) ) {
                    var tmp = [groups[key]['name'], false];
                    for ( var k = 0; k < groups[key]["members"].length; k ++ ) {
                        if ( groups[key]["members"][k]['username'].match( member_id ) )
                            tmp[1] = true;
                    }
                }
                memberGroups.push(tmp);
            }
            return memberGroups;
        };

        for ( i = 0; i < numMembers; i++ ) {
            var member = $scope.members[i];
            $scope.originalMembers[member[0]] = {name: member[2],
                                                 email: member[1],
                                                 groups: memberGroups(member[0])};
        }

        $scope.selectedMembers = JSON.parse(JSON.stringify($scope.originalMembers));
    };


    $scope.updateMembers = function() {
        if ( $scope.members.length < 1 ) {
            $scope.errors = "selected members list is empty";
            return;
        }
        var compareGroups = function (A, B) {
            var groups = [];
            var A_dict = {};
            var x;
            for ( x = 0; x < A.length; x++ ) {
                A_dict[A[x][0]] = A[x][1];
            }
            for ( x = 0; x < B.length; x++) {
                if ( !A_dict[B[x][0]] != !B[x][1] ) {
                    groups.push(B[x]);
                }
            }
            return groups;
        };

        var x;
        for ( var key in $scope.originalMembers ) {
            if ( $scope.originalMembers.hasOwnProperty(key) ) {
                var groups = compareGroups($scope.originalMembers[key].groups,
                                           $scope.selectedMembers[key].groups);
                for( x = 0; x < groups.length; x++) {
                    var url = '/project/membership/' + $scope.selectedProject + '/' + key + '/';
                    if ( groups[x][1] ) {
                        $http.put(url, {groups: [groups[x][0]]})
                        .success( function (data) {
                            console.log("Add Member ", $scope.originalMembers[key].name);
                        })
                        .error( function (data) {
                            $scope.errors = data;
                        });
                    }
                    else {
                        $http.delete(url + groups[x][0])
                        .success( function (data) {
                            console.log("Remove Member ", $scope.originalMembers[key].name);
                        })
                        .error( function (data) {
                            $scope.errors = data;
                        });
                    }
                }

            }
        }
    };

    init();
}
