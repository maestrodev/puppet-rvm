require 'spec_helper_acceptance'

describe 'rvm' do
  # host variables
  let(:osfamily) { fact('osfamily') }
  let(:osname) { fact('operatingsystem') }
  let(:osversion) { fact('operatingsystemrelease') }

  # rvm config
  let(:rvm_path) { '/usr/local/rvm/' }

  # list of currently supported interpreters
  # https://github.com/rvm/rvm/blob/master/config/known

  # ruby 2.7 config
  let(:ruby27_version) { 'ruby-2.7.0' } # chosen for RVM binary support across nodesets
  let(:ruby27_environment) { "#{rvm_path}environments/#{ruby27_version}" }
  let(:ruby27_bin) { "#{rvm_path}rubies/#{ruby27_version}/bin/" }
  let(:ruby27_gems) { "#{rvm_path}gems/#{ruby27_version}/gems/" }
  let(:ruby27_gemset) { 'myproject' }
  let(:ruby27_and_gemset) { "#{ruby27_version}@#{ruby27_gemset}" }

  # ruby 2.6 config
  let(:ruby26_version) { 'ruby-2.6.5' } # chosen for RVM binary support across nodesets
  let(:ruby26_environment) { "#{rvm_path}environments/#{ruby26_version}" }
  let(:ruby26_bin) { "#{rvm_path}rubies/#{ruby26_version}/bin/" }
  let(:ruby26_gems) { "#{rvm_path}gems/#{ruby26_version}/gems/" }
  let(:ruby26_gemset) { 'myproject' }
  let(:ruby26_and_gemset) { "#{ruby26_version}@#{ruby26_gemset}" }

  # passenger baseline configuration
  let(:service_name) do
    case osfamily
    when 'Debian'
      'apache2'
    when 'RedHat'
      'httpd'
    end
  end
  let(:mod_dir) do
    case osfamily
    when 'Debian'
      '/etc/apache2/mods-available/'
    when 'RedHat'
      '/etc/httpd/conf.d/'
    end
  end
  let(:rackapp_user) do
    case osfamily
    when 'Debian'
      'www-data'
    when 'RedHat'
      'apache'
    end
  end
  let(:rackapp_group) do
    case osfamily
    when 'Debian'
      'www-data'
    when 'RedHat'
      'apache'
    end
  end
  let(:conf_file) { "#{mod_dir}passenger.conf" }
  let(:load_file) { "#{mod_dir}passenger.load" }

  # baseline manifest
  let(:manifest) do
    <<-EOS
      if $::osfamily == 'RedHat' {
        class { 'epel':
          before => Class['rvm'],
        }
      }

      # ensure rvm doesn't timeout finding binary rubies
      #class { 'rvm::rvmrc':
      #  max_time_flag => '20',
      #} ->

      class { 'rvm': } ->
      rvm::system_user { 'vagrant': }
  EOS
  end

  it 'rvm should install and configure system user' do
    # Run it twice and test for idempotency
    apply_manifest(manifest, catch_failures: true)
    apply_manifest(manifest, catch_changes: true)
    shell('/usr/local/rvm/bin/rvm list') do |r|
      r.stdout.should =~ Regexp.new(Regexp.escape('# No rvm rubies installed yet.'))
      r.exit_code.should be_zero
    end
  end

  context 'when installing rubies' do
    let(:manifest) do
      super() + <<-EOS
        rvm_system_ruby {
          '#{ruby27_version}':
            ensure      => 'present',
            default_use => false;
          '#{ruby26_version}':
            ensure      => 'present',
            default_use => false;
        }
      EOS
    end

    it 'installs with no errors' do
      apply_manifest(manifest, catch_failures: true)
      apply_manifest(manifest, catch_changes: true)
    end

    it 'reflects installed rubies' do
      shell('/usr/local/rvm/bin/rvm list') do |r|
        r.stdout.should =~ Regexp.new(Regexp.escape(ruby27_version.to_s))
        r.stdout.should =~ Regexp.new(Regexp.escape(ruby26_version.to_s))
        r.exit_code.should be_zero
      end
    end

    context 'and installing gems' do
      let(:gem_name) { 'simple-rss' } # used because has no dependencies
      let(:gem_version) { '1.3.1' }

      let(:gemset_manifest) do
        manifest + <<-EOS
          rvm_gemset {
            '#{ruby27_and_gemset}':
              ensure  => present,
              require => Rvm_system_ruby['#{ruby27_version}'];
          }
          rvm_gem {
            '#{ruby27_and_gemset}/#{gem_name}':
              ensure  => '#{gem_version}',
              require => Rvm_gemset['#{ruby27_and_gemset}'];
          }
          rvm_gemset {
            '#{ruby26_and_gemset}':
              ensure  => present,
              require => Rvm_system_ruby['#{ruby26_version}'];
          }
          rvm_gem {
            '#{ruby26_and_gemset}/#{gem_name}':
              ensure  => '#{gem_version}',
              require => Rvm_gemset['#{ruby26_and_gemset}'];
          }
        EOS
      end

      it 'installs with no errors' do
        apply_manifest(gemset_manifest, catch_failures: true)
        apply_manifest(gemset_manifest, catch_changes: true)
      end

      it 'reflects installed gems and gemsets' do
        shell("/usr/local/rvm/bin/rvm #{ruby27_version} gemset list") do |r|
          r.stdout.should =~ Regexp.new(Regexp.escape("\n=> (default)"))
          r.stdout.should =~ Regexp.new(Regexp.escape("\n   global"))
          r.stdout.should =~ Regexp.new(Regexp.escape("\n   #{ruby27_gemset}"))
          r.exit_code.should be_zero
        end

        shell("/usr/local/rvm/bin/rvm #{ruby26_version} gemset list") do |r|
          r.stdout.should =~ Regexp.new(Regexp.escape("\n=> (default)"))
          r.stdout.should =~ Regexp.new(Regexp.escape("\n   global"))
          r.stdout.should =~ Regexp.new(Regexp.escape("\n   #{ruby26_gemset}"))
          r.exit_code.should be_zero
        end
      end
    end
  end

  context 'when installing jruby' do
    let(:jruby_version) { 'jruby-1.7.6' }

    let(:manifest) do
      super() + <<-EOS
        rvm_system_ruby { '#{jruby_version}':
          ensure      => 'present',
          default_use => false;
        }
      EOS
    end

    it 'installs with no errors' do
      apply_manifest(manifest, catch_failures: true)
      apply_manifest(manifest, catch_changes: true)
    end

    it 'reflects installed rubies' do
      shell('/usr/local/rvm/bin/rvm list') do |r|
        r.stdout.should =~ Regexp.new(Regexp.escape(jruby_version.to_s))
        r.exit_code.should be_zero
      end
    end
  end

  context 'when installing passenger 6.0.x' do
    let(:passenger_version) { '6.0.9' }
    let(:passenger_domain) { 'passenger3.example.com' }

    let(:passenger_ruby) { "#{rvm_path}wrappers/#{ruby27_version}/ruby" }
    let(:passenger_root) { "#{ruby27_gems}passenger-#{passenger_version}" }
    # particular to 3.0.x (may or may not also work with 2.x?)
    let(:passenger_module_path) { "#{passenger_root}/ext/apache2/mod_passenger.so" }

    let(:manifest) do
      super() + <<-EOS
        rvm_system_ruby {
          '#{ruby27_version}':
            ensure      => 'present',
            default_use => false,
        }
        class { 'apache':
          service_enable => false, # otherwise detects changes in 2nd run in ubuntu and docker
        }
        class { 'rvm::passenger::apache':
          version            => '#{passenger_version}',
          ruby_version       => '#{ruby27_version}',
          mininstances       => '3',
          maxinstancesperapp => '0',
          maxpoolsize        => '30',
          spawnmethod        => 'smart-lv2',
        }
        /* a simple ruby rack 'hello world' app */
        file { '/var/www/passenger':
          ensure  => directory,
          owner   => '#{rackapp_user}',
          group   => '#{rackapp_group}',
          require => Class['rvm::passenger::apache'],
        }
        file { '/var/www/passenger/config.ru':
          ensure  => file,
          owner   => '#{rackapp_user}',
          group   => '#{rackapp_group}',
          content => "app = proc { |env| [200, { \\"Content-Type\\" => \\"text/html\\" }, [\\"hello <b>world</b>\\"]] }\\nrun app",
          require => File['/var/www/passenger'] ,
        }
        apache::vhost { '#{passenger_domain}':
          port    => '80',
          docroot => '/var/www/passenger/public',
          docroot_group => '#{rackapp_group}' ,
          docroot_owner => '#{rackapp_user}' ,
          custom_fragment => "PassengerRuby  #{passenger_ruby}\\nRailsEnv  development" ,
          default_vhost => true ,
          require => File['/var/www/passenger/config.ru'] ,
        }
      EOS
    end

    it 'installs with no errors' do
      # Run it twice and test for idempotency
      apply_manifest(manifest, catch_failures: true)
      # swapping expectations under Ubuntu 12.04, 14.04 - apache2-prefork-dev is being purged/restored by puppetlabs/apache, which is beyond the scope of this module
      if osname == 'Ubuntu' && ['12.04', '14.04'].include?(osversion)
        apply_manifest(manifest, expect_changes: true)
      else
        apply_manifest(manifest, catch_changes: true)
      end

      shell("/usr/local/rvm/bin/rvm #{ruby27_version} do #{ruby27_bin}gem list passenger | grep \"passenger (#{passenger_version})\"").exit_code.should be_zero
    end

    it 'is running' do
      service(service_name) do |s|
        s.should_not be_enabled
        s.should be_running
      end
    end

    it 'answers' do
      shell('/usr/bin/curl localhost:80') do |r|
        r.stdout.should =~ %r{^hello <b>world</b>$}
        r.exit_code.should == 0
      end
    end

    it 'outputs status via passenger-status' do
      shell("rvmsudo_secure_path=1 /usr/local/rvm/bin/rvm #{ruby27_version} do passenger-status") do |r|
        # spacing may vary
        r.stdout.should =~ %r{[\-]+ General information [\-]+}
        r.exit_code.should == 0
      end
    end

    it 'module loading should be configured as expected' do
      file(load_file) do |f|
        f.should contain "LoadModule passenger_module #{passenger_module_path}"
      end
    end

    it 'module behavior should be configured as expected' do
      file(conf_file) do |f|
        f.should contain "PassengerRoot \"#{passenger_root}\""
        f.should contain "PassengerRuby \"#{passenger_ruby}\""
      end
    end
  end
end
