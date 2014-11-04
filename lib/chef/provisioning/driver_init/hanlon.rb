require 'chef/provisioning/hanlon_driver/hanlon_driver'

Chef::Provisioning.register_driver_class('hanlon', Chef::Provisioning::HanlonDriver::HanlonDriver)
