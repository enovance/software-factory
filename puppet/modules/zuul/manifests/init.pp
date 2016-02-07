#
# Copyright (C) 2014 eNovance SAS <licensing@enovance.com>
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

class zuul {

  require hosts

  $fqdn = hiera('fqdn')
  $url = hiera('url')
  $logs = hiera('logs')
  $hosts = hiera('hosts')
  $jenkins_rsa = hiera('jenkins_rsa')
  $gerrit_host = "gerrit.${fqdn}"

  $pub_html_path = '/var/www/zuul'
  $gitweb_path = '/usr/libexec/git-core'

  file {'/var/www/zuul/index.html':
    ensure => file,
    mode   => '0644',
    source => 'puppet:///modules/zuul/index.html',
  }

  exec { 'virtualhost_reload':
    command => '/usr/bin/systemctl reload httpd'
  }

  file {'/etc/httpd/conf.d/zuul.conf':
    ensure  => file,
    mode    => '0640',
    owner   => $::httpd_user,
    group   => $::httpd_user,
    content => template('zuul/zuul.site.erb'),
    notify  => Exec['virtualhost_reload'],
  }

  file {'zuul_init':
    ensure => file,
    path   => '/lib/systemd/system/zuul.service',
    mode   => '0555',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/zuul/zuul.service',
  }

  file {'zuul_merger_init':
    ensure => file,
    path   => '/lib/systemd/system/zuul-merger.service',
    mode   => '0555',
    group  => 'root',
    owner  => 'root',
    source => 'puppet:///modules/zuul/zuul-merger.service',
  }

  group { 'zuul':
    ensure => present,
  }

  user { 'zuul':
    ensure     => present,
    home       => '/var/lib/zuul',
    shell      => '/bin/bash',
    gid        => 'zuul',
    managehome => true,
    require    => Group['zuul'],
  }

  file {'/var/log/zuul/':
    ensure  => directory,
    mode    => '0755',
    owner   => 'zuul',
    group   => 'zuul',
    require => [User['zuul'], Group['zuul']],
  }

  file {'/etc/sysconfig/zuul':
    content => template('graphite/statsd.environment.erb'),
  }

  file {'/etc/zuul':
    ensure  => directory,
    mode    => '0750',
    owner   => 'zuul',
    group   => 'zuul',
    require => [User['zuul'], Group['zuul']],
  }

  file {'/var/lib/zuul/':
    ensure  => directory,
    mode    => '0755',
    owner   => 'zuul',
    group   => 'zuul',
    require => [User['zuul'], Group['zuul']],
  }

  file {'/var/lib/zuul/.ssh':
    ensure  => directory,
    mode    => '0755',
    owner   => 'zuul',
    group   => 'zuul',
    require => File['/var/lib/zuul/'],
  }

  file {'/var/lib/zuul/.ssh/id_rsa':
    ensure  => file,
    mode    => '0400',
    owner   => 'zuul',
    group   => 'zuul',
    content => inline_template('<%= @jenkins_rsa %>'),
    require => File['/var/lib/zuul/.ssh'],
  }

  file {'/var/run/zuul/':
    ensure  => directory,
    mode    => '0755',
    owner   => 'zuul',
    group   => 'zuul',
    require => [User['zuul'], Group['zuul']],
  }

  file {'/etc/zuul/logging.conf':
    ensure  => file,
    mode    => '0644',
    owner   => 'zuul',
    group   => 'zuul',
    source  => 'puppet:///modules/zuul/logging.conf',
    require => File['/etc/zuul'],
  }

  file {'/etc/zuul/gearman-logging.conf':
    ensure  => file,
    mode    => '0644',
    owner   => 'zuul',
    group   => 'zuul',
    source  => 'puppet:///modules/zuul/gearman-logging.conf',
    require => File['/etc/zuul'],
  }

  file {'/etc/zuul/merger-logging.conf':
    ensure  => file,
    mode    => '0644',
    owner   => 'zuul',
    group   => 'zuul',
    source  => 'puppet:///modules/zuul/merger-logging.conf',
    require => File['/etc/zuul'],
  }

  file {'/etc/zuul/zuul.conf':
    ensure  => file,
    mode    => '0644',
    owner   => 'zuul',
    group   => 'zuul',
    content => template('zuul/zuul.conf.erb'),
    require => [File['/etc/zuul/logging.conf'],
                File['/etc/zuul/gearman-logging.conf'],
                File['/etc/zuul/merger-logging.conf']],
  }

  file {'/etc/zuul/layout.yaml':
    ensure  => file,
    mode    => '0644',
    owner   => 'zuul',
    group   => 'zuul',
    require => [File['/etc/zuul']],
  }
}
