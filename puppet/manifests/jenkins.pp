Package {
  allow_virtual => false,
}

$httpd_user = "apache"

node default {
  include ssh_keys_jenkins
  include jenkins
  # jjb also deploys zuul and nodepool
  include jjb
}
