class gnocchi {

  require hosts

  $fqdn = hiera('fqdn')
  $mysql_db_address = "mysql.${fqdn}"
  $mysql_db_secret = hiera('creds_gnocchi_sql_pwd')
  $mysql_db_username = 'gnocchi'
  $mysql_db = 'gnocchi'

  file {'/etc/gnocchi':
    ensure  => directory,
  }

  file {'/etc/gnocchi/gnocchi.conf':
    ensure  => file,
    mode    => '0755',
    content => template('gnocchi/gnocchi.conf.erb'),
    require => File['/etc/gnocchi'],
  }

  file {'/etc/gnocchi/api-paste.ini':
    ensure  => file,
    mode    => '0755',
    source  => 'puppet:///modules/gnocchi/api-paste.ini',
    require => File['/etc/gnocchi'],
  }

  file {'/etc/gnocchi/policy.json':
    ensure  => file,
    mode    => '0755',
    source  => 'puppet:///modules/gnocchi/policy.json',
    require => File['/etc/gnocchi'],
  }

  file {'/lib/systemd/system/gnocchi-api.service':
    ensure  => file,
    mode    => '0755',
    source  => 'puppet:///modules/gnocchi/gnocchi-api.service',
  }

  file {'/lib/systemd/system/gnocchi-metricd.service':
    ensure  => file,
    mode    => '0755',
    source  => 'puppet:///modules/gnocchi/gnocchi-metricd.service',
  }

  file {'/lib/systemd/system/gnocchi-statsd.service':
    ensure  => file,
    mode    => '0755',
    source  => 'puppet:///modules/gnocchi/gnocchi-statsd.service',
  }

  file {'/root/archive_policy.sql':
    ensure  => file,
    mode    => '0755',
    source  => 'puppet:///modules/gnocchi/archive_policy.sql',
  }

  service {'gnocchi-api':
    ensure    => running,
    enable    => true,
    hasstatus => true,
    require   => [
        File['/lib/systemd/system/gnocchi-api.service'],
        File['/lib/systemd/system/gnocchi-metricd.service'],
        File['/lib/systemd/system/gnocchi-statsd.service'],
        File['/etc/gnocchi/gnocchi.conf'],
        File['/etc/gnocchi/api-paste.ini'],
        File['/etc/gnocchi/policy.json'],
	]
  }

  service {'gnocchi-metricd':
    ensure    => running,
    enable    => true,
    hasstatus => true,
    require   => [
        File['/lib/systemd/system/gnocchi-api.service'],
        File['/lib/systemd/system/gnocchi-metricd.service'],
        File['/lib/systemd/system/gnocchi-statsd.service'],
        File['/etc/gnocchi/gnocchi.conf'],
        File['/etc/gnocchi/api-paste.ini'],
        File['/etc/gnocchi/policy.json'],
	]
  }

  service {'gnocchi-statsd':
    ensure    => running,
    enable    => true,
    hasstatus => true,
    require   => [
        File['/lib/systemd/system/gnocchi-api.service'],
        File['/lib/systemd/system/gnocchi-metricd.service'],
        File['/lib/systemd/system/gnocchi-statsd.service'],
        File['/etc/gnocchi/gnocchi.conf'],
        File['/etc/gnocchi/api-paste.ini'],
        File['/etc/gnocchi/policy.json'],
	]
  }

  exec {'gnocchi-dbsync':
    path        => '/usr/bin',
	subscribe   => File['/etc/gnocchi/gnocchi.conf'],
	refreshonly => true,
  }

  exec {'gnocchi-archive-policy':
    command     => 'mysql -u ${mysql_db_username} -p${mysql_db_secret} -h ${mysql_db_address} ${mysql_db} < /root/archive_policy.sql',
    path        => '/usr/bin/:/bin/',
    require     => Exec['gnocchi-dbsync'],
    subscribe   => File['/root/archive_policy.sql'],
    refreshonly => true,
    returns     => [0, 5],
  }

}
