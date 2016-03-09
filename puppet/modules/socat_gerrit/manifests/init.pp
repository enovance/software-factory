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

class socat_gerrit {

  exec {'reload_units':
    command     => 'systemctl daemon-reload',
    path        => '/usr/sbin/:/usr/bin/:/bin/',
    refreshonly => true,
  }

  file {'/lib/systemd/system/socat_gerrit.service':
    ensure => file,
    mode   => '0640',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/socat_gerrit/socat_gerrit.service',
    notify => [Exec['reload_units'], Service['socat_gerrit']],
  }

  service {'socat_gerrit':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    require    => Exec['reload_units'],
  }
}
