Package {
  allow_virtual => false,
}

$httpd_user = "apache"

node default {
  include mysql
}
