#
# Copyright (C) 2016 Red Hat
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

class nodepool {

  $jenkins_rsa_pub = hiera('jenkins_rsa_pub')
  $nodepool = hiera('nodepool')
  $nodepool_rsa = hiera('jenkins_rsa')
  $fqdn = hiera('fqdn')
  $url = hiera('url')

  $jenkins_host = "jenkins.${fqdn}"
  $jenkins_password = hiera('creds_jenkins_user_password')
  $nodepool_mysql_address = "mysql.${fqdn}"
  $nodepool_sql_password = hiera('creds_nodepool_sql_pwd')
  $mysql_root_pwd = hiera('creds_mysql_root_pwd')

  if $nodepool['disabled'] {
    $running = false
    $enabled = false
  }
  else {
    $running = true
    $enabled = true
  }

  group { 'nodepool':
    ensure => present,
  }

  user { 'nodepool':
    ensure     => present,
    home       => '/var/lib/nodepool',
    shell      => '/sbin/nologin',
    gid        => 'nodepool',
    managehome => true,
    require    => Group['nodepool'],
  }

  file { '/var/lib/nodepool/.ssh':
    require    => User['nodepool'],
    ensure     => directory,
    owner      => 'nodepool',
    group      => 'nodepool',
    mode       => '0700',
  }

  file { '/var/lib/nodepool/.ssh/id_rsa':
    require => File['/var/lib/nodepool/.ssh'],
    ensure  => file,
    owner   => 'nodepool',
    group   => 'nodepool',
    mode    => '0400',
    content => inline_template('<%= @nodepool_rsa %>'),
  }

  file { 'nodepool_service':
    path    => '/lib/systemd/system/nodepool.service',
    owner   => 'nodepool',
    source  => 'puppet:///modules/nodepool/nodepool.service',
  }

  file { '/var/run/nodepool':
    ensure => directory,
    owner  => 'nodepool',
  }

  file { '/var/log/nodepool/':
    ensure => directory,
    owner  => 'nodepool',
    mode   => '0700',
  }

  file {'/etc/sysconfig/nodepool':
    content => template('graphite/statsd.environment.erb'),
  }

  file {'/opt/nodepool':
    ensure => directory,
    owner  => 'nodepool',
  }

  file { '/etc/nodepool':
    ensure => directory,
    owner  => 'nodepool',
  }

  file { '/etc/nodepool/scripts':
    ensure  => directory,
    owner   => 'nodepool',
    require => [File['/etc/nodepool']],
  }

  file { '/etc/nodepool/scripts/authorized_keys':
    owner   => 'nodepool',
    mode    => '0600',
    content => inline_template('<%= @jenkins_rsa_pub %>'),
    require => [File['/etc/nodepool/scripts']],
  }

  file { '/etc/nodepool/nodepool.logging.conf':
    owner   => 'nodepool',
    source  => 'puppet:///modules/nodepool/nodepool.logging.conf',
    require => [File['/etc/nodepool']],
  }

  # This file will be used by the conf merger
  file { '/etc/nodepool/_nodepool.yaml':
    owner   => 'nodepool',
    content => template('nodepool/nodepool.yaml.erb'),
    require => [File['/etc/nodepool']],
  }

  file { '/etc/nodepool/secure.conf':
    owner   => 'nodepool',
    mode   => '0400',
    content => template('nodepool/secure.conf.erb'),
    require => [File['/etc/nodepool']],
  }

  file {'/etc/nodepool/logging.conf':
    source => 'puppet:///modules/nodepool/logging.conf',
    require => [File['/etc/nodepool/']],
  }


  file { '/usr/local/bin/sf-nodepool-conf-update.sh':
    ensure => file,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
    content => template('nodepool/sf-nodepool-conf-update.sh.erb'),
  }

  service { 'nodepool':
    ensure     => $running,
    enable     => $enabled,
    hasrestart => true,
    require    => [File['nodepool_service'],
                    File['/var/run/nodepool'],
                    File['/var/log/nodepool/'],
                    File['/etc/nodepool/_nodepool.yaml'],
                    File['/etc/nodepool/nodepool.logging.conf'],
                    File['/etc/nodepool/scripts'],
                    File['/etc/nodepool/logging.conf'],
                    ],
  }

  bup::scripts{ 'nodepool_scripts':
    name           => 'nodepool',
    backup_script  => 'nodepool/backup.sh.erb',
    restore_script => 'nodepool/restore.sh.erb',
  }
}
