node default {
  include monit
  include managesf
  include cauth
  include cauth_client
  include commonservices-apache
  include replication
}
