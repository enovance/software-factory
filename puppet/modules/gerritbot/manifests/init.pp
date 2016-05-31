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

class gerritbot {

  $gerritbot = hiera('gerritbot')
  $gerritbot_rsa = hiera('jenkins_rsa')

  file { '/var/lib/gerritbot/.ssh':
    ensure     => directory,
    owner      => 'gerritbot',
    group      => 'gerritbot',
    mode       => '0700',
  }

  file { '/var/lib/gerritbot/.ssh/id_rsa':
    require => File['/var/lib/gerritbot/.ssh'],
    ensure  => file,
    owner   => 'gerritbot',
    group   => 'gerritbot',
    mode    => '0400',
    content => inline_template('<%= @gerritbot_rsa %>'),
  }

  file { '/var/log/gerritbot':
    ensure  => directory,
    owner   => 'gerritbot',
    group   => 'gerritbot',
  }

  file { '/var/run/gerritbot':
    ensure  => directory,
    owner   => 'gerritbot',
    group   => 'gerritbot',
  }

  file { '/etc/gerritbot/gerritbot.conf':
    ensure  => file,
    mode    => '0600',
    owner   => 'gerritbot',
    group   => 'gerritbot',
    content => template('gerritbot/gerritbot.conf.erb'),
  }

  file { '/etc/gerritbot/logging.conf':
    ensure  => file,
    owner   => 'gerritbot',
    group   => 'gerritbot',
    source  => 'puppet:///modules/gerritbot/logging.conf',
  }

  file { 'gerritbot_service':
    path    => '/lib/systemd/system/gerritbot.service',
    source  => 'puppet:///modules/gerritbot/gerritbot.service',
  }

  if $gerritbot['disabled'] {
    service { 'gerritbot':
      ensure     => false,
      enable     => false,
      hasrestart => true,
      require    => File['/lib/systemd/system/gerritbot.service'],
      subscribe  => [File['/etc/gerritbot/gerritbot.conf'],
                     File['/etc/gerritbot/logging.conf'],
                     File['/var/run/gerritbot']],
    }
  }
}
