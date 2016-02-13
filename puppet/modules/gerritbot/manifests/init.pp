# Copyright (c) 2016 Red Hat, Inc.
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

  file { '/var/log/gerritbot':
    ensure  => directory,
  }

  file { '/etc/gerritbot.conf':
    ensure  => file,
    mode    => '0600',
    content => template('gerritbot/gerritbot.conf.erb'),
    replace => false,
  }

  file { '/etc/gerritbot_logging.config':
    ensure  => file,
    source  => 'puppet:///modules/gerritbot/gerritbot_logging.config',
  }

  file { '/etc/gerritbot_channels.yaml':
    ensure  => file,
    source  => 'puppet:///modules/gerritbot/gerritbot_channels.yaml',
    replace => false,
  }

  file { 'gerritbot_service':
    path    => '/lib/systemd/system/gerritbot.service',
    source  => 'puppet:///modules/gerritbot/gerritbot.service',
  }

  service { 'gerritbot':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    require    => [File['/lib/systemd/system/gerritbot.service']],
    subscribe  => [File['/etc/gerritbot.conf'],
                   File['/etc/gerritbot_channels.yaml'],
                   File['/etc/gerritbot_logging.config']],
  }

}
