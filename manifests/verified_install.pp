# Encapsuate the initial installation and an obligatory verification
class rvm::verified_install (
  # These are passed from rvm::system
  $environment=undef,
  $actual_version=undef) {
    Exec {
      path        => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
      environment => $environment,
      unless      => 'test -e  /usr/local/rvm/bin/rvm',
    }
    exec { 'download-detached-key':
      command     => "curl -sf https://raw.githubusercontent.com/rvm/rvm/master/binscripts/rvm-installer.asc > /tmp/rvm-installer.asc",
    }->
    # I thought of feeding curl output to gpg in order to remove less files during
    # cleanup, but let's run exactly the file we've verified
    exec { 'download-installer':
      command     => "curl -sf https://raw.githubusercontent.com/rvm/rvm/master/binscripts/rvm-installer > /tmp/rvm-installer",
    }->
    exec { 'verify-installer':
      command     => "gpg --verify /tmp/rvm-installer.asc /tmp/rvm-installer",
    }->
    exec { 'run-installer':
      command     => "bash /tmp/rvm-installer --version ${actual_version}",
    }->
    exec { 'cleanup-tmp':
      command     => "rm /tmp/rvm-installer{,.asc}",
    }
}
