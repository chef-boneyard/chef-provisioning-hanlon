require 'chef/provisioning'

class Chef::Resource::HanlonImage < Chef::Resource::LWRPBase
  self.resource_name = 'hanlon_image'

  def initialize(driver_url, config)
    super
    @driver = run_context.chef_provisioning.current_driver
  end

  actions :create, :nothing #, :delete # forthcoming
  default_action :create

  attribute :driver

  def after(&block)
    block ? @after = block : @after
  end

  # Are we interested in Chef's cloning behavior here?
  def load_prior_resource(*args)
    Chef::Log.debug("Overloading #{resource_name}.load_prior_resource with NOOP")
  end
end
