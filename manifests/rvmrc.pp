# Configure the /etc/rvmrc file
class rvm::rvmrc(
  $manage_group = $rvm::params::manage_group,
  $template = 'rvm/rvmrc.erb',
  $umask = 'u=rwx,g=rwx,o=rx',
  $max_time_flag = undef,
  $autoupdate_flag = false,
  $silence_path_mismatch_check_flag = undef,
  $project_rvmrc = false,
  $gem_options = "--no-rdoc --no-ri",
  $install_on_use_flag = false,
  $gemset_create_on_use_flag = false,
  $ignore_gemsets_flag = false,
  ) inherits rvm::params {

  if $manage_group { include rvm::group }

  Class['rvm::rvmrc'] <- Class['rvm']

  # I did used typed parameters for compatibility with Puppet <4
  validate_bool( $autoupdate_flag )
  validate_bool( $project_rvmrc )
  validate_bool( $install_on_use_flag )
  validate_bool( $gemset_create_on_use_flag )
  validate_bool( $ignore_gemsets_flag )

  file { '/etc/rvmrc':
    content => template($template),
    mode    => '0664',
    owner   => 'root',
    group   => $rvm::params::group,
    before  => Exec['system-rvm'],
  }
}
