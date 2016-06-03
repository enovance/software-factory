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

class sfmysql {
    include ::bup

    $fqdn = hiera('fqdn')
    $mysql_root_pwd = hiera('creds_mysql_root_pwd')

    exec { 'set_mysql_root_password':
        unless  => "mysqladmin -uroot -p${mysql_root_pwd} status",
        path    => '/bin:/usr/bin',
        command => "mysqladmin -uroot password ${mysql_root_pwd}",
        require => Service['mariadb'],
    }

    service {'mariadb':
        ensure     => running,
        name       => 'mariadb',
        enable     => true,
        hasrestart => true,
        hasstatus  => true,
        provider   => 'systemd',
    }

    bup::scripts{ 'mysql_scripts':
      name           => 'mysql',
      backup_script  => 'sfmysql/backup.sh.erb',
      restore_script => 'sfmysql/restore.sh.erb',
    }

    file_line{ 'utf8_clients':
      path => '/etc/my.cnf',
      line => 'character_set_server = utf8',
    }
}
