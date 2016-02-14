Package {
  allow_virtual => false,
}

$httpd_user = 'apache'

node default {
  include ::sfbase
  include ::bup
  include ::postfix
  include ::monit

  # gnocchi and grafana
  include ::sfgnocchi
  include ::grafana
}
