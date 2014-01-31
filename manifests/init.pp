class rvm(
  $version=undef,
  $install_rvm=true,
  $install_dependencies=false,
  $group='rvm',
  $system_users=[],
  $system_rubies={}) inherits rvm::params {

  if $install_rvm {

    # rvm has now autolibs enabled by default so let it manage the dependencies
    if $install_dependencies {
      class { 'rvm::dependencies':
        before => Class['rvm::system']
      }
    }

    ensure_resource('group', $group, {'ensure' => 'present' })
    ensure_resource('class', 'rvm::rvmrc')

    class { 'rvm::system':
      version => $version;
    }
  }

  rvm::system_user{ $system_users: }
  create_resources('rvm_system_ruby', $system_rubies, {'ensure' => present})
}
