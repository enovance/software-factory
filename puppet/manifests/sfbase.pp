Package {
  allow_virtual => false,
}

$httpd_user = "apache"

node default {
  include ssh_keys
  include monit
  include postfix
  include sfbase
  include https_cert
  include cauth_client
}
