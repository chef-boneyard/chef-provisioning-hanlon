$:.unshift(File.dirname(__FILE__) + '/lib')
require 'chef/provisioning/hanlon_driver/version'

Gem::Specification.new do |s|
  s.name = 'chef-provisioning-hanlon'
  s.version = Chef::Provisioning::HanlonDriver::VERSION
  s.platform = Gem::Platform::RUBY
  s.extra_rdoc_files = ['README.md', 'LICENSE' ]
  s.summary = 'Provisioner for creating hanlon PXE policies and models with Chef Provisioning.'
  s.description = s.summary
  s.author = 'John Ewart'
  s.email = 'jewart@chef.io'
  s.homepage = 'https://github.com/chef/chef-provisioning-hanlon'

  s.required_ruby_version = ">= 2.1.9"

  s.add_dependency 'chef'
  s.add_dependency 'chef-provisioning', '>= 1.0', '< 3.0'
  s.add_dependency 'hanlon-api', '~> 0.0'

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rake'

  s.bindir       = "bin"
  s.executables  = %w( )

  s.require_path = 'lib'
  s.files = %w(Rakefile LICENSE README.md) + Dir.glob("{distro,lib,tasks,spec}/**/*", File::FNM_DOTMATCH).reject {|f| File.directory?(f) }
end
