require 'chef/provider/lwrp_base'
require 'chef/provisioning/hanlon_driver/hanlon_driver'
require 'pry'

class Chef::Provider::HanlonModel < Chef::Provider::LWRPBase
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
    matching_models=Hanlon::Api::Model.filter('label',nr.label)
    
    if not matching_models.empty?
      our_model = matching_models.first
      new_resource.updated_by_last_action(false)
    else

      Chef::Log.info "No model! Creating '#{nr.label}'"
      Chef::Log.info "Looking up image '#{nr.image}'"
      # esx: aka path_prefix = esxi
      # has esxi_version
      
      matching_images = Hanlon::Api::Image.filter('filename', nr.image)
      our_image = matching_images.first
      
      model_options = {
        label: nr.label,
        template: nr.template,
        image_uuid: our_image.uuid,
        req_metadata_params: nr.metadata
      }
      
      new_model=Hanlon::Api::Model.create model_options
      result = new_model.instance_variable_get(:@result)
      if result && [500,400].include?(result['code'])
        raise result['description']
      end
      new_resource.updated_by_last_action(true)
    end
  end
  
  action :delete do
    config_hanlon_api
    matching_models=Hanlon::Api::Model.filter('label',nr.label)
    return if matching_models.empty?
    our_model = matching_models.first
    Hanlon::Api::Model.destroy(our_model.uuid)
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
    @current_resource = Chef::Resource::HanlonModel.new(nr.name)
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
