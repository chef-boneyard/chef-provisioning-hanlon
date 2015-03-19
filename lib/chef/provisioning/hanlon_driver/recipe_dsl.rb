require 'chef/provisioning/hanlon_driver/driver'
require 'chef/resource/hanlon_image'
require 'chef/provider/hanlon_image'


class Chef
  module DSL
    module Recipe
      def with_hanlon_driver(provider, driver_options = nil, &block)
        #config = Cheffish::MergedConfig.new({ :driver_options => driver_options }, run_context.config)
        driver = Driver.from_provider(provider, config)
        run_context.chef_provisioning.with_driver(driver, &block)
      end
    end
  end
end
