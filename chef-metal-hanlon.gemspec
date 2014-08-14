$:.unshift(File.dirname(__FILE__) + '/lib')
require 'chef_metal_hanlon/version'

Gem::Specification.new do |s|
  s.name = 'chef-metal-hanlon'
  s.version = ChefMetalHanlon::VERSION
  s.platform = Gem::Platform::RUBY
  s.extra_rdoc_files = ['README.md', 'LICENSE' ]
  s.summary = 'Provisioner for creating hanlon containers in Chef Metal.'
  s.description = s.summary
  s.author = 'Tom Duffield'
  s.email = 'tom@getchef.com'
  s.homepage = 'https://github.com/opscode/chef-metal-hanlon'

  s.add_dependency 'chef'
  s.add_dependency 'chef-metal', '~> 0.9'
  s.add_dependency 'hanlon-api', '~> 0.0'

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rake'

  s.bindir       = "bin"
  s.executables  = %w( )

  s.require_path = 'lib'
  s.files = %w(Rakefile LICENSE README.md) + Dir.glob("{distro,lib,tasks,spec}/**/*", File::FNM_DOTMATCH).reject {|f| File.directory?(f) }
end
