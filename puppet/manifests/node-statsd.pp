Package {
  allow_virtual => false,
}

$httpd_user = 'apache'

node default {
  include ::sfbase
  include ::bup
  include ::postfix
  include ::monit

  # graphite, statsd and grafana
  include ::graphite
  include ::grafana
}
