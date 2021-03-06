# == Class: teamspeak
#
# Manages Teamspeak install.
#
# === Parameters
#
# [*version*]
#   Version of Teamspeak server to download.
#
# [*arch*]
#    Defines the architecture of the binary of Teamspeak that we're
#    downloading, defaults to your systems arch. Manually setting this
#    to "i386" will not automatically resolve i386 => x86, this is the arch
#    used in the download URI.
#
# [*mirror*]
#    Defines the architecture mirror URL to download from, defaults to
#    'http://dl.4players.de/ts/releases/<%=version%>/teamspeak3-server_linux-<%=download_arch%>-<%=version%>.tar.gz'.
#
# [*license_file*]
#    Source link to license file, optional. 
#
# === Examples
#
#  include teamspeak
#
#  class { teamspeak:
#      version => '3.0.11.3',
#      arch    => 'x86',
#  }
#
#  class { teamspeak:
#      version      => '3.0.11.3',
#      license_file => 'puppet:///modules/roles/teamspeak/licensekey.dat'
#  }
#
# === Authors
#
# William Roush <william.roush@roushtech.net>
#
# === Copyright
#
# Copyright 2015 William Roush
#

class teamspeak (
    $version         = $teamspeak::params::version,
    $arch            = $teamspeak::params::download_arch,
    $mirror          = $teamspeak::params::mirror,
    $license_file    = undef,
    $user            = 'teamspeak',
    $group           = 'teamspeak',
    $init            = 'init', # or systemd
    $home            = '/opt/teamspeak',
    $service         = 'teamspeak',
    ) inherits ::teamspeak::params  {

  package { 'wget':
    ensure => present,
  }
  
  group { "$group":
    ensure => present,
  }
  
  user { "$user":
    ensure     => present,
    managehome => true,
    home       => $home,
    groups     => $group,
    require    => Group[$group],
  }
  
  $teamspeak_dirs = [
    $home,
    "${home}/downloads",
  ]
  
  file { $teamspeak_dirs:
    ensure  => directory,
    owner   => $user,
    group   => $group,
    mode    => '750',
    require => [
      User[$user],
      Group[$group],
    ],
  }
  
  $parsed_mirror = inline_template($mirror)
  exec { 'download_teamspeak':
    command => "wget -q ${parsed_mirror}",
    path    => '/usr/bin',
    cwd     => "${home}/downloads",
    user    => $user,
    group   => $group,
    creates => "${home}/downloads/teamspeak3-server_linux-${arch}-${version}.tar.gz",
    require => [
      File["${home}/downloads"],
      User[$user],
      Package['wget'],
    ],
  }
  
  exec { 'unpack_teamspeak':
    command     => "tar -xzf ${home}/downloads/teamspeak3-server_linux-${arch}-${version}.tar.gz -C /opt/teamspeak/downloads",
    path        => '/bin',
    user        => $user,
    refreshonly => true,
    subscribe   => Exec['download_teamspeak'],
  }
  
  exec { 'move_teamspeak':
    command     => "mv teamspeak3-server_linux-${arch}/* $home",
    cwd         => "${home}/downloads",
    path        => '/bin',
    user        => $user,
    refreshonly => true,
    subscribe   => Exec['unpack_teamspeak'],
  }
  
  file { 'delete_temp_teamspeak':
    ensure    => absent,
    path      => "${home}/downloads/teamspeak3-server_linux-${arch}",
    subscribe => Exec['move_teamspeak'],
    recurse   => true,
    purge     => true,
    force     => true,
  }
  
  if $license_file != undef {
    file { 'teamspeak_license':
      ensure => present,
      path   => "${home}/licensekey.dat",
      source => $license_file,
      owner  => $user,
      group  => $group,
      mode   => 660,
    }
  }
  
  service { $service:
    ensure   => running,
    enable   => true,
  }
  

  case $init {
    'init': {
      include teamspeak::service::init
    }
    default: {
      include teamspeak::service::systemd
    }
  }

}