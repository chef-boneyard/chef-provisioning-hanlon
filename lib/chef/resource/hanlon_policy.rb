require 'chef/provisioning'

class Chef::Resource::HanlonPolicy < Chef::Resource::LWRPBase
  self.resource_name = 'hanlon_policy'

  actions :create, :delete, :nothing #, :update # forthcoming
  default_action :create

  attribute :driver
  attribute :label, kind_of: String, name_attribute: true, required: true
  attribute :model, required: true
  attribute :template, required: true
  # Policy Templates: (should be some type of check against model/image)
  # boot_local            Policy used to adding existing nodes to Hanlon.       
  # discover_only         Policy used to discover new nodes.                    
  # linux_deploy          Policy for deploying a Linux-based operating system.  
  # vmware_hypervisor     Policy for deploying a VMware hypervisor.             
  # windows_deploy        Policy for deploying a Windows operating system.      
  # xenserver_hypervisor  Policy for deploying a XenServer hypervisor.          

  attribute :tags, required: true
  attribute :enabled, required: false, default: true
  attribute :maximum, required: false, default: 0
  attribute :broker, required: false
  attribute :uuid, required: false #since we lookup by label, might use this for updates

  def after(&block)
    block ? @after = block : @after
  end

  # Are we interested in Chef's cloning behavior here?
  def load_prior_resource(*args)
    Chef::Log.debug("Overloading #{resource_name}.load_prior_resource with NOOP")
  end
end
