Package {
  allow_virtual => false,
}

$httpd_user = 'apache'

node default {
  include ::sfbase
  include ::bup
  include ::postfix
  include ::monit

  # Managesf
  include ::apache
  include ::managesf
  include ::cauth
  include ::cauth_client
  include ::gateway
  include ::etherpad
  include ::lodgeit
  include ::replication

  include ::edeploy_server
  include ::auto_backup
  include ::socat_gerrit
}
