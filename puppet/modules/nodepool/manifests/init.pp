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

class nodepool ($settings = hiera_hash('nodepool', '')) {
  
  $provider = "systemd"
#  group { 'nodepool':
#
#    ensure => present,
#  }
#
#  user { 'nodepool':
#    ensure => present,
#    home => '/home/nodepool',
#    system => true,
#    managehome => true,
#    comment => 'Nodepool user',
#    require => Group['nodepool'],
#  }

  file { 'nodepool_service':
    path  => '/lib/systemd/system/nodepool.service',
    #owner => 'nodepool',
    owner => 'zuul',
    content => template('nodepool/nodepool.service.erb'),
    #require => User['nodepool'],
  }

  file { '/var/run/nodepool':
    ensure  => directory,
    #owner   => 'nodepool',
    owner => 'zuul',
    #require => [User['nodepool'], Group['nodepool']],
  }

  file { '/var/log/nodepool/':
    ensure  => directory,
    #owner   => 'nodepool',
    owner => 'zuul',
    #require => [User['nodepool'], Group['nodepool']],
  }

  file { '/etc/nodepool':
    ensure  => directory,
    #owner   => 'nodepool',
    owner => 'zuul',
    #require => [User['nodepool'], Group['nodepool']],
  }

  file { '/etc/nodepool/scripts':
    ensure  => directory,
    #owner   => 'nodepool',
    owner => 'zuul',
    require => [File['/etc/nodepool']]
    #require => [User['nodepool'], Group['nodepool']],
  }

  file { '/etc/nodepool/scripts/setup.sh':
    #owner => 'nodepool',
    owner => 'zuul',
    mode   => '0555',
    source => 'puppet:///modules/nodepool/setup.sh',
    require => [File['/etc/nodepool/scripts'],
                #User['nodepool']
                ]
  }

  file { '/etc/nodepool/scripts/setup2.sh':
    #owner => 'nodepool',
    owner => 'zuul',
    mode   => '0555',
    source => 'puppet:///modules/nodepool/setup2.sh',
    require => [File['/etc/nodepool/scripts'],
                #User['nodepool']
                ]
  }

  file { '/etc/nodepool/nodepool.yaml':
    #owner => 'nodepool',
    owner => 'zuul',
    content => template('nodepool/nodepool.yaml.erb'),
    require => [File['/etc/nodepool'],
                #User['nodepool']
                ]
  }

  file { '/etc/nodepool/nodepool.logging.conf':
    #owner => 'nodepool',
    owner => 'zuul',
    content => template('nodepool/nodepool.logging.conf'),
    require => [File['/etc/nodepool'],
                #User['nodepool']
                ]
  }

  file { '/etc/nodepool/sshkey':
    owner => 'zuul',
    mode   => '0600',
    source => 'puppet:///modules/nodepool/nodepool',
    require => File['/etc/nodepool']
  }

  file { '/var/lib/jenkins/.ssh/nodepool':
    owner => 'jenkins',
    mode   => '0600',
    source => 'puppet:///modules/nodepool/nodepool',
  }

  service { 'nodepool':
    ensure      => running,
    enable      => true,
    hasrestart  => true,
    provider    => $provider,
    require     => [File['nodepool_service'],
                    File['/var/run/nodepool'],
                    File['/var/log/nodepool/'],
                    File['/etc/nodepool/nodepool.yaml'],
                    File['/etc/nodepool/nodepool.logging.conf'],
                    File['/etc/nodepool/scripts/setup.sh'],
                    ],
    #subscribe   => [File['/home/gerrit/gerrit.war'],
  }

}
