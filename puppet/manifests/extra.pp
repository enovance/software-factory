Package {
  allow_virtual => false,
}

$httpd_user = "apache"

node default {
  include etherpad
  include lodgeit
  include redmine
  include cauth_client
  include monit
}
