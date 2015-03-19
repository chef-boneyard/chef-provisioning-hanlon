require 'chef/provider/lwrp_base'
require 'chef/provisioning/hanlon_driver/driver'
require 'pry'

class Chef::Provider::HanlonImage < Chef::Provider::LWRPBase
  use_inline_resources

  def whyrun_supported?
    true
  end

  action :create do
    binding.pry
  end

  def current_resource_exists?
    # maybe we should poll the api
    @current_resource.action != [ :delete ]
  end

  def new_driver
    run_context.chef_provisioning.driver_for(new_resource.driver)
  end
  
  def load_current_resource
    
  end
end
