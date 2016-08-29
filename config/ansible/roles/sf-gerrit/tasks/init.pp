class gerrit {
  include ::monit
  include ::apache
  include ::bup
  include ::systemctl

  file { 'gerrit_service':
    require => [Exec['gerrit-initial-init'],
                File['wait4mariadb']],
    notify  => Exec['systemctl_reload'],
  }

  # Gerrit first initialization, must be run only when gerrit.war changes
  exec { 'gerrit-initial-init':
    user        => 'gerrit',
    command     => '/usr/bin/java -jar /home/gerrit/gerrit.war init -d /home/gerrit/site_path --batch --no-auto-start',
    subscribe   => File['/home/gerrit/gerrit.war'],
    refreshonly => true,
    logoutput   => on_failure,
  }

  # Gerrit reindex after first initialization
  exec { 'gerrit-reindex':
    user        => 'gerrit',
    command     => '/usr/bin/java -jar /home/gerrit/gerrit.war reindex -d /home/gerrit/site_path',
    require     => [Exec['gerrit-initial-init']],
    subscribe   => File['/home/gerrit/gerrit.war'],
    refreshonly => true,
    logoutput   => on_failure,
  }

  # Init default in Gerrit. Require a running gerrit but
  # must be done the first time after gerrit-init-init
  exec {'gerrit-init-firstuser':
    command     => '/root/gerrit-firstuser-init.sh',
    logoutput   => on_failure,
    subscribe   => Exec['gerrit-initial-init'],
    require     => [Service['gerrit'],
                    File['/root/gerrit-firstuser-init.sql'],
                    File['/root/gerrit_admin_rsa']],
    refreshonly => true,
  }
  exec {'gerrit-init-acl':
    command     => '/root/gerrit-set-default-acl.sh',
    logoutput   => on_failure,
    subscribe   => Exec['gerrit-init-firstuser'],
    require     => [Service['gerrit'],
                    File['/root/gerrit_data_source/project.config'],
                    File['/root/gerrit_data_source/ssh_wrapper.sh'],
                    File['/home/gerrit/gerrit.war']],
    refreshonly => true,
  }
  exec {'gerrit-init-jenkins':
    command     => '/root/gerrit-set-jenkins-user.sh',
    logoutput   => on_failure,
    subscribe   => [Exec['gerrit-init-firstuser'], File['/root/gerrit-set-jenkins-user.sh']],
    require     => Service['gerrit'],
    refreshonly => true,
  }

  # Gerrit process restart only when one of the configuration files
  # change or when gerrit-initial-init has been triggered
  service { 'gerrit':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    provider   => $provider,
    require    => [Exec['gerrit-initial-init'],
                    File['gerrit_service'],
                    Exec['systemctl_reload'],
                    File['/var/www/git/gitweb.cgi']],
    subscribe  => [File['/home/gerrit/gerrit.war'],
                    File['/home/gerrit/site_path/etc/gerrit.config'],
                    File['/root/gerrit-firstuser-init.sql'],
                    File['/home/gerrit/site_path/etc/secure.config']],
  }

  # Ensure mount point exists
  file { '/home/gerrit/site_path/git':
    ensure  => directory,
    owner   => 'gerrit',
    require => File['/home/gerrit/site_path'],
  }

  # Install a default replication.config file
  file { '/home/gerrit/site_path/etc/replication.config':
    ensure  => file,
    owner   => 'gerrit',
    group   => 'gerrit',
    mode    => '0644',
    source  => 'puppet:///modules/gerrit/replication.config',
    replace => false,
  }

  file { '/etc/monit.d/gerrit':
    ensure  => file,
    content => template('gerrit/monit.erb'),
    notify  => Service['monit'],
  }

  bup::scripts{ 'gerrit_scripts':
    name           => 'gerrit',
    backup_script  => 'gerrit/backup.sh.erb',
    restore_script => 'gerrit/restore.sh.erb',
  }

  file { '/home/gerrit/site_path/etc/GerritSiteHeader.html':
    ensure => file,
    owner  => 'gerrit',
    group  => 'gerrit',
    source => 'puppet:///modules/gerrit/GerritSiteHeader.html',
  }

}
