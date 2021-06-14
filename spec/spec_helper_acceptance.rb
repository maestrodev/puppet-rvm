require 'voxpupuli/acceptance/spec_helper_acceptance'

configure_beaker do |host|
  install_module_from_forge('puppet-epel', '>= 3.0.1 < 4.0.0') if fact_on(host, 'os.name') == 'CentOS'
  install_module_from_forge('puppetlabs-apache', '>= 5.7.0 < 7.0.0')
end
