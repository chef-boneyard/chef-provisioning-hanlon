require 'chef/provisioning'

class Chef::Resource::HanlonImage < Chef::Resource::LWRPBase
  self.resource_name = 'hanlon_image'

  actions :create, :delete, :nothing #, :delete # forthcoming
  default_action :create

  attribute :driver
  attribute :name, kind_of: String, name_attribute: true, required: true
  attribute :type, required: true
  attribute :path, required: false #defaults to name
  attribute :version, required: true
  attribute :description, required: true
  attribute :uuid

  def after(&block)
    block ? @after = block : @after
  end

  # Are we interested in Chef's cloning behavior here?
  def load_prior_resource(*args)
    Chef::Log.debug("Overloading #{resource_name}.load_prior_resource with NOOP")
  end
end
