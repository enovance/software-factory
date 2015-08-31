node default {
  # these are imported from modules/base
  include disable_root_pw_login
  include ssh_keys
  include postfix
  include monit
  include ntpserver
  include https_cert
  include monit
  include mysql

  include cauth
  include cauth_client
  include bup

  include commonservices-apache
  include commonservices-socat

  include redmine
  include gerrit

  include managesf
  include jenkins
  include ssh_keys_gerrit
  include jjb
  include nodepool

  include etherpad
  include lodgeit
}
