require 'chef/provisioning'

class Chef::Resource::HanlonModel < Chef::Resource::LWRPBase
  self.resource_name = 'hanlon_model'

  actions :create, :delete, :nothing #, :update # forthcoming
  default_action :create

  attribute :driver
  attribute :label, kind_of: String, name_attribute: true, required: true
  attribute :template, required: true
  # Should we validate this in realtime or store it here?
  #   Model Templates:
  #     Template Name                     Description                 
  # boot_local              Noop model to add existing nodes          
  # centos_6                CentOS 6 Model                            
  # coreos_in_memory        CoreOS In-Memory                          
  # coreos_stable           CoreOS Stable                             
  # debian_wheezy           Debian Wheezy Model                       
  # discover_only           Noop model to discover new nodes          
  # opensuse_12             OpenSuSE Suse 12 Model                    
  # oraclelinux_6           Oracle Linux 6 Model                      
  # redhat_6                RedHat 6 Model                            
  # redhat_7                RedHat 7 Model                            
  # sles_11                 SLES 11 Model                             
  # ubuntu_oneiric          Ubuntu Oneiric Model                      
  # ubuntu_precise          Ubuntu Precise Model                      
  # ubuntu_precise_ip_pool  Ubuntu Precise Model (IP Pool)            
  # vmware_esxi_5           VMware ESXi 5 Deployment                  
  # windows_2012_r2         Windows 2012 R2                           
  # xenserver_boston        Citrix XenServer 6.0 (boston) Deployment  
  # xenserver_tampa         Citrix XenServer 6.1 (tampa) Deployment   

  attribute :metadata, required: true
  attribute :image, required: true
  attribute :uuid, required: false #since we lookup by label, might use this for updates

  def after(&block)
    block ? @after = block : @after
  end

  # Are we interested in Chef's cloning behavior here?
  def load_prior_resource(*args)
    Chef::Log.debug("Overloading #{resource_name}.load_prior_resource with NOOP")
  end
end
