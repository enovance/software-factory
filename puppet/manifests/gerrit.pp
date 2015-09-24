Package {
  allow_virtual => false,
}

$httpd_user = "apache"

node default {
  include monit
  include cauth_client
  include ssh_keys_gerrit
  include gerrit
  include bup
}
