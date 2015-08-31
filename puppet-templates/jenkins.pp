node default {
  include monit
  include jenkins
  include jjb
  include nodepool
}
