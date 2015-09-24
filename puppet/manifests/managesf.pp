Package {
  allow_virtual => false,
}

$httpd_user = "apache"

node default {
  # Managesf
  include apache
  include managesf
  include cauth
  include cauth_client
  include commonservices-apache
  include replication
  include edeploy_server
  include auto_backup
}
