require 'chef/provisioning'

class Chef::Resource::HanlonImage < Chef::Resource::LWRPBase
  self.resource_name = 'hanlon_image'

  #def initialize(driver_url, config)
  #  super
  #  @driver = run_context.chef_provisioning.current_driver
  #end

  actions :create, :delete, :nothing #, :delete # forthcoming
  default_action :create

  attribute :driver
  attribute :name, kind_of: String, name_attribute: true, required: true
  attribute :type, required: true
  attribute :path, required: true
  attribute :version, required: true
  attribute :description, required: true

  def after(&block)
    block ? @after = block : @after
  end

  # Are we interested in Chef's cloning behavior here?
  def load_prior_resource(*args)
    Chef::Log.debug("Overloading #{resource_name}.load_prior_resource with NOOP")
  end
end
