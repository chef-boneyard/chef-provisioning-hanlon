require 'chef/provider/lwrp_base'
require 'chef/provisioning/hanlon_driver/hanlon_driver'
require 'pry'

class Chef::Provider::HanlonImage < Chef::Provider::LWRPBase
  use_inline_resources

  #def initialize(*args)
  #  super
  #end

  
  def whyrun_supported?
    # I think we need a working @current_resource
    false #true
  end

  def nr
    new_resource
  end

  def config_hanlon_api
    Hanlon::Api.configure do |config|
      config.api_url = hanlon_url
    end
  end

  action :create do
    config_hanlon_api
    #nr, path defaults to name,  but stored images vary based on type...
    # would be nice to do async call this map function across all images
    # might be nice to cache this list across the chef-client run as well
    # maybe in run_state?
    hi = Hanlon::Api::Image.list.map{|i| Hanlon::Api::Image.find i}
    current_image = hi.find do |img|
      if nr.path
        nr.path == img.os_name ||
          nr.path == img.filename
      else
        nr.name == img.os_name ||
          nr.name == img.filename
      end
    end
    if not current_image
      image=Hanlon::Api::Image.create({type: nr.type,
                                      path: nr.path || nr.name,
                                      description: nr.description,
                                      name: nr.name,
                                      version: nr.version})
      new_resource.updated_by_last_action(true)
    end
  end

  action :delete do
    config_hanlon_api
    nr.path ||= nr.name 
    list = Hanlon::Api::Image.filter('os_name', nr.name)
    if list
      match = list.first
      Hanlon::Api::Image.destroy(match.uuid)
    end
    new_resource.updated_by_last_action(true)
  end

  def current_resource_exists?
    # maybe we should poll the api
    @current_resource.action != [ :delete ]
  end

  def hanlon_url
    driver = run_context.chef_provisioning.current_driver
    driver.sub('hanlon:','http://')
  end

  def load_current_resource
    @current_resource = Chef::Resource::HanlonImage.new(nr.name)
    # #config_hanlon_api
    # match = Hanlon::Api::Image.filter(
    #   'os_name', nr.name).first
    # # only basing searches on os_name and filename
    # #to_a.select{ |i|
    # #i.os_version == nr.version}.first
    # match ||= Hanlon::Api::Image.filter(
    #   'filename', nr.name).first
    # #.to_a.select{ |i|
    # # i.os_version == nr.version}.first
    # # there seems to be a bug here
    # if match 
    #   @current_resource.type match.path_prefix
    #   # we default path to name, but if we load it when not requested
    #   # it doesn't match and we set it up again
    #   if nr.path
    #     @current_resource.path match.filename
    #   else
    #     @current_resource.path nr.path
    #   end
    #   @current_resource.description match.description
    #   # these are different between OS and MK images
    #   @current_resource.version  match.os_version || match.iso_version
    #   @current_resource.uuid  match.uuid
    # end
    # @current_resource
    # binding.pry
  end
end
