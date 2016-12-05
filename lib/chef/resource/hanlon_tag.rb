require 'chef/provisioning'

class Chef::Resource::HanlonTag < Chef::Resource::LWRPBase
  self.resource_name = 'hanlon_tag'

  #def initialize(driver_url, config)
  #  super
  #  @driver = run_context.chef_provisioning.current_driver
  #end

  actions :create, :delete, :nothing #, :delete # forthcoming
  default_action :create

  attribute :driver
  attribute :name, kind_of: String, name_attribute: true, required: true
  attribute :tag, required: true
  # attribute :match, required: true, kind_of: Array
  # matches should have some validation, but this is just to get to an mvp
  def after(&block)
    block ? @after = block : @after
  end

  # Are we interested in Chef's cloning behavior here?
  def load_prior_resource(*args)
    Chef::Log.debug("Overloading #{resource_name}.load_prior_resource with NOOP")
  end
end
