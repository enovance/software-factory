Package {
  allow_virtual => false,
}

$httpd_user = 'apache'

node default {
  include ::sfbase
  include ::bup
  include ::postfix
  include ::monit

  # Gerrit
  include ::cauth_client
  include ::ssh_keys_gerrit
  include ::gerrit
}
