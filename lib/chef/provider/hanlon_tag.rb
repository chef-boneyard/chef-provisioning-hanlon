require 'chef/provider/lwrp_base'
require 'chef/provisioning/hanlon_driver/hanlon_driver'
require 'pry'

class Chef::Provider::HanlonTag < Chef::Provider::LWRPBase
  use_inline_resources

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

  # TODO keying off something other than the iso filename
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

  def hanlon_url
    driver = run_context.chef_provisioning.current_driver
    driver.sub('hanlon:','http://')
  end
  
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
