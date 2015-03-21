require 'chef/provider/lwrp_base'
require 'chef/provisioning/hanlon_driver/hanlon_driver'
require 'pry'

class Chef::Provider::HanlonImage < Chef::Provider::LWRPBase
  use_inline_resources

  #def initialize(*args)
  #  super
  #end

  
  def whyrun_supported?
    true
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
    if Hanlon::Api::Image.filter('filename', nr.path) == []
      image=Hanlon::Api::Image.create({type: nr.type,
                                      path: nr.path,
                                      description: nr.description,
                                      name: nr.name,
                                      version: nr.version})
      new_resource.updated_by_last_action(true)
    end
  end

  action :delete do
    config_hanlon_api
    list = Hanlon::Api::Image.filter('filename', nr.path)
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

  # I'm not sure if we need to load the current resource 
  # until we support updates / changes
  # def load_current_resource
  #   @current_resource = Chef::Resource::HanlonImage.new(@new_resource.name)
  #   config_hanlon_api
  #   list = Hanlon::Api::Image.filter('filename', nr.path)
  #   if list
  #     existing = list.first
  #     @current_resource.type = existing.path_prefix #maybe... need to find all types
  #     @current_resource.path = existing.filename
  #     @current_resource.description = existing.description
  #     @current_resource.version = existing.os_version
      
  #     image=Hanlon::Api::Image.create({type: nr.type ,
  #                                      path: nr.path,
  #                                      description: nr.description,
  #                                      name: nr.name,
  #                                      version: nr.version})
  #   end
  # end
end
