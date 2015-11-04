#
# Copyright (C) 2015 Red Hat
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

class graphite {

  file { '/opt/graphite':
    ensure => directory,
    owner  => 'apache',
  }

  file { '/opt/graphite/storage/':
    ensure => directory,
    owner  => 'apache',
    require     => File['/opt/graphite']
  }

  file { '/etc/httpd/conf.d/graphite-web.conf':
    ensure => file,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/graphite/graphite-web.conf',
  }

  file { '/etc/statsd/config.js':
    ensure => file,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/graphite/config.js',
  }

  file { '/etc/graphite-web/local_settings.py':
    ensure => file,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/graphite/local_settings.py',
  }

  file { '/etc/carbon':
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }

  file { '/etc/carbon/storage-schemas.conf':
    ensure => file,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/graphite/storage-schemas.conf',
    require     => File['/etc/carbon']
  }

  exec { 'sync_graphite_db':
    command     => '/usr/lib/python2.7/site-packages/graphite/manage.py syncdb --noinput',
    logoutput   => true,
    unless      => '/usr/bin/test -f /opt/graphite/storage/graphite.db',
    require     => [
		    File['/etc/statsd/config.js'],
		    File['/etc/graphite-web/local_settings.py'],
		    File['/opt/graphite/storage/']],
  }

  file { '/opt/graphite/storage/graphite.db':
    ensure  => file,
    mode   => '0755',
    owner   => 'apache',
    group   => 'apache',
    require => Exec['sync_graphite_db']
  }

  service { 'statsd':
    ensure     => true,
    enable     => true,
    hasrestart => true,
  }

  service { 'carbon-cache':
    ensure     => true,
    enable     => true,
    hasrestart => true,
  }

  service { 'grafana-server':
    ensure     => true,
    enable     => true,
    hasrestart => true,
  }

  file { '/tmp/grafana.sql':
    ensure => file,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/graphite/grafana.sql',
  }

  file { '/etc/grafana/grafana.ini':
    ensure => file,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
    content => template('graphite/grafana.ini'),
  }

  exec { 'sync_grafana_db':
    command     => '/usr/bin/sqlite3 /var/lib/grafana/grafana.db < /tmp/grafana.sql',
    logoutput   => true,
    unless      => '/usr/bin/test -f /opt/graphite/storage/graphite.db',
    require     => [Service['grafana-server'],
                    File['/etc/grafana/grafana.ini'],
                    File['/tmp/grafana.sql']],
  }

}
