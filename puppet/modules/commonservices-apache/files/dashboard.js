var sfDashboard = angular.module('sfDashboard', []);

function mainController($scope, $http) {
    $scope.data = {};

    function get_projects() {
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
    }

    get_projects();

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
}
