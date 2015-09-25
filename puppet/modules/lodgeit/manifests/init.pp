class lodgeit ($lodgeit = hiera_hash('lodgeit', '')) {

  require hosts
  include apache

  file {'init':
    path   => '/lib/systemd/system/lodgeit.service',
    ensure => file,
    mode   => '0755',
    source =>'puppet:///modules/lodgeit/lodgeit.service',
    require => File['/srv/lodgeit/lodgeit/manage.py'],
  }

  file { "/srv/lodgeit/lodgeit/manage.py":
    ensure  => present,
    mode    => '0755',
    replace => true,
    owner   => $httpd_user,
    group   => $httpd_user,
    content => template('lodgeit/manage.py.erb'),
    notify  => Service['lodgeit'],
  }

  file { "/srv/lodgeit/lodgeit/lodgeit/urls.py":
    ensure  => present,
    mode    => '0755',
    replace => true,
    owner   => $httpd_user,
    group   => $httpd_user,
    source  => 'puppet:///modules/lodgeit/urls.py',
    notify  => Service['lodgeit'],
  }

  service {'lodgeit':
    enable     => true,
    ensure     => running,
    hasstatus  => true,
    require    => [File['init'],
                   File['/srv/lodgeit/lodgeit/manage.py'],
                   File['/srv/lodgeit/lodgeit/lodgeit/urls.py']],
  }

  file { '/var/www/static/lodgeit':
    ensure  => link,
    target  => '/srv/lodgeit/lodgeit/lodgeit/static/',
  }

}
