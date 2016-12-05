require 'chef/provider/lwrp_base'
require 'chef/provisioning/hanlon_driver/hanlon_driver'
require 'pry'

class Chef::Provider::HanlonPolicy < Chef::Provider::LWRPBase
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
    matching_policies=Hanlon::Api::Policy.filter('label',nr.label)
    
    if not matching_policies.empty?
      our_policy = matching_policies.first
      new_resource.updated_by_last_action(false)
    else
      
      Chef::Log.info "No Policy! Creating '#{nr.label}'"
      Chef::Log.info "Looking up Model '#{nr.model}'"
      # esx: aka path_prefix = esxi
      # has esxi_version

      # We should support model lookup via uuid as well
      # Possible via resource lookup
      matching_models = Hanlon::Api::Model.filter('label', nr.model)
      our_model = matching_models.first
      binding.pry if our_model.nil?
      
      model_options = {
        label: nr.label,
        # label_prefix: nr.label,
        template: nr.template,
        model_uuid: our_model.uuid,
        tags: nr.tags,
        maximum: nr.maximum,
        enabled: nr.enabled,
        req_metadata_params: {}
      }
      
      new_policy=Hanlon::Api::Policy.create model_options
      result = new_policy.instance_variable_get(:@result)
      if result && [500,400].include?(result['code'])
        # we should raise a proper exception or do something chef-like
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
