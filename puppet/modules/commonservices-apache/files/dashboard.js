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
                get_projects();
            })
            .error(function(data) {
            $scope.errors = data;
            }).finally(function () {
                $scope.loading = false;
            });
    };

    $scope.deleteProject = function(name) {
        $scope.errors = false;
        $scope.loading = true;

        $http.delete('/manage/project/' + name)
            .success(function(data) {
                $scope.data = {};
                get_projects();
            })
            .error(function(data) {
            $scope.errors = data;
            }).finally(function () {
                $scope.loading = false;
            });
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

            selectedGroup.members.splice(index, 1);

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

    $scope.membershipForm = function(project) {
        $scope.selectedProject = project;
    };

    init();
}
