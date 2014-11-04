
require 'chef/provisioning/driver'
require 'chef/provisioning/machine/unix_machine'

require 'chef/provisioning/convergence_strategy/hanlon_broker'
require 'chef/provisioning/hanlon_driver/version'
require 'chef/provisioning/hanlon_driver/pxe_machine'


require 'yaml'
require 'hanlon/api'

class Chef
module Provisioning
module HanlonDriver
  # Provisions machines using Hanlon
  class HanlonDriver < Chef::Provisioning::Driver

    attr_reader :connection
    attr_reader :hanlon_url

    # URL scheme:
    # hanlon:<path>
    # canonical URL calls realpath on <path>
    def self.from_url(driver_url, config)
      HanlonDriver.new(driver_url, config)
    end

    def initialize(driver_url, config)
      super
      scheme, url = driver_url.split(':', 2)

      if url
        @hanlon_url = url

        if url !~ /^http.*/
          url = "http://#{url}"
        end

        Chef::Log.debug("Setting Hanlon URL to #{url}")
        Hanlon::Api.configure do |config|
          config.api_url = url
        end
      end

    end

    def self.canonicalize_url(driver_url, config)
      scheme, url = driver_url.split(':', 2)
      [ "hanlon:#{url}", config ]
    end


    def allocate_machine(action_handler, machine_spec, machine_options)
      # TODO: policy information
      machine_spec.location = {
          'driver_url' => driver_url,
          'driver_version' => Chef::Provisioning::HanlonDriver::VERSION,
          'allocated_at' => Time.now.utc.to_s,
          'host_node' => action_handler.host_node,
      }
    end

    def ready_machine(action_handler, machine_spec, machine_options)
      # TODO: Support UUIDs in machine options
      # verify our image exists
      image = Hanlon::Api::Image.find(machine_options[:image_uuid])
      if image.nil?
        raise "Can't construct a boot descriptor for a non-existant image"
      end

      Chef::Log.debug "Using image #{image.inspect}"

      machine_for(machine_spec, machine_options)
    end




    def allocate_image(action_handler, image_spec, image_options, machine_spec)
      raise 'Nope.'
    end

    def ready_image(action_handler, image_spec, image_options)
      raise 'Nuh-uh'
    end

    # Connect to machine without acquiring it
    def connect_to_machine(machine_spec, machine_options)
      Chef::Log.debug('Connect to machine!')
    end

    def destroy_machine(action_handler, machine_spec, machine_options)
      raise 'Nothin doin.'
    end

    def stop_machine(action_handler, node)
      Chef::Log.debug("Stop machine: #{node.inspect}")
    end

    def driver_url
      "hanlon:#{@hanlon_url}"
    end

    def start_machine(action_handler, machine_spec, machine_options)
      Chef::Log.debug("Hanlon start machine: #{machine_spec.inspect}")
    end

    def machine_for(machine_spec, machine_options)
      Chef::Provisioning::HanlonDriver::PxeMachine.new(machine_spec,
                                      convergence_strategy_for(machine_spec, machine_options))
    end

    def transport_for(machine_spec)
      nil
    end

    def convergence_strategy_for(machine_spec, machine_options)
      @hanlon_broker_strategy ||= begin
        Chef::Provisioning::ConvergenceStrategy::HanlonBroker.
            new(machine_options, machine_spec, config)
      end
    end

  end
end
end
end
