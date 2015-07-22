require 'chef/provisioning/convergence_strategy/precreate_chef_objects'
require 'pathname'
require 'fileutils'
require 'digest/md5'
require 'thread'
require 'hanlon/api'

module Chef::Provisioning
  class ConvergenceStrategy
    class HanlonBroker < Chef::Provisioning::ConvergenceStrategy

      # convergence_options is a hash of setup convergence_options, including:
      # - :chef_server
      # - :allow_overwrite_keys
      # - :source_key, :source_key_path, :source_key_pass_phrase
      # - :private_key_options
      # - :ohai_hints
      # - :public_key_path, :public_key_format
      # - :admin, :validator
      # - :chef_client_timeout
      # - :client_rb_path, :client_pem_path
      # - :chef_version, :prerelease, :package_cache_path
      def initialize(machine_options, machine_spec, config)
        convergence_options = machine_options[:convergence_options]
        convergence_options = Cheffish::MergedConfig.new(convergence_options, {
            :client_rb_path => '/etc/chef/client.rb',
            :client_pem_path => '/etc/chef/client.pem'
        })
        super(convergence_options, config)
        @chef_version ||= convergence_options[:chef_version]
        # TODO: take this from @chef_server instead - not yet though.
        @chef_server_url = convergence_options[:chef_server_url]
        @install_sh_url = convergence_options[:install_sh_url] || 'https://www.chef.io/chef/install.sh'
        @machine_options = machine_options
        puts "CONVERGENCE_OPTIONS: #{convergence_options.inspect}"
        puts "CONFIG: #{config.inspect}"
      end

      attr_reader :client_rb_path
      attr_reader :client_pem_path
      attr_reader :chef_server
      attr_reader :chef_server_url

      def setup_convergence(action_handler, machine)
        Chef::Log.debug('Hanlon Broker Convergence setup_convergence')
        node_name = machine.node['name']

        client_keys = generate_keys(action_handler)
        create_chef_objects(action_handler, machine, client_keys)

        # make sure the model exists
        model = find_or_create_hanlon_model(@machine_options)
        Chef::Log.debug "Using model #{model.inspect}"

        # make sure the broker exists
        broker = find_or_create_hanlon_broker(node_name, client_keys)
        Chef::Log.debug "Using broker #{broker.inspect}"

        # Check to see if the policy exists
        policy = find_or_create_hanlon_policy(node_name, @machine_options, model, broker)
        Chef::Log.debug "Using policy #{policy.inspect}"
      end

      def converge(action_handler, machine)
        Chef::Log.debug('Hanlon Broker Convergence converge')
        # NOOP, hanlon will install and do this for us.
      end

      def cleanup_convergence(action_handler, machine_spec)
        Chef::Log.debug('Hanlon Broker Convergence cleanup_convergence')
      end


      private

      def create_chef_objects(action_handler, machine, public_key)
        _convergence_options = convergence_options
        _chef_server = chef_server
        # Save the node and create the client keys and client.
        Chef::Provisioning.inline_resource(action_handler) do
          # Create client
          chef_client machine.name do
            chef_server _chef_server
            source_key public_key
            output_key_path _convergence_options[:public_key_path]
            output_key_format _convergence_options[:public_key_format]
            admin _convergence_options[:admin]
            validator _convergence_options[:validator]
          end

          # Create node
          # TODO strip automatic attributes first so we don't race with "current state"
          chef_node machine.name do
            chef_server _chef_server
            raw_json machine.node
          end
        end

        # If using enterprise/hosted chef, fix acls
        #if chef_server[:chef_server_url] =~ /\/+organizations\/.+/
        #  grant_client_node_permissions(action_handler, chef_server, machine.name, ["read", "update"])
        #end
      end

      def generate_keys(action_handler)
        # If the server does not already have keys, create them and upload
        server_private_key = nil

        _convergence_options = convergence_options
        Chef::Provisioning.inline_resource(action_handler) do
          private_key 'in_memory' do
            path :none
            if _convergence_options[:private_key_options]
              _convergence_options[:private_key_options].each_pair do |key,value|
                send(key, value)
              end
            end
            after { |resource, private_key| server_private_key = private_key }
          end
        end

        server_private_key
      end

      def find_or_create_hanlon_policy(node_name, machine_options, model, broker)
        # TODO -- this is not the best key but works for now.
        policy_label = "#{machine_options[:policy][:label_prefix]} - #{node_name}"
        Hanlon::Api::Policy.list.each do |policy_uuid|
          p = Hanlon::Api::Policy.find(policy_uuid)
          if p.label == policy_label
            return p
          end
        end

        Chef::Log.debug "No policy! Creating '#{policy_label}'"

        Hanlon::Api::Policy.create({
                                       label: policy_label,
                                       model_uuid: model.uuid,
                                       broker_uuid: broker.uuid,
                                       template: machine_options[:policy][:template],
                                       tags: machine_options[:policy][:tags],
                                       enabled: true,
                                       maximum: 1
                                   })

      end

      def find_or_create_hanlon_broker(node_name, client_keys)
        client_pem = client_keys.to_pem
        broker_name = "chef/provisioning_broker_#{node_name}"

        Hanlon::Api::Broker.list.each do |broker_uuid|
          b = Hanlon::Api::Broker.find(broker_uuid)
          if b.name == broker_name
            return b
          end
        end

        Chef::Log.debug "No broker found, creating '#{broker_name}'"

        Hanlon::Api::Broker::ChefMetal.create({
                                       :name => broker_name,
                                       :plugin => 'chef/provisioning',
                                       :description => 'Chef Provisioning Broker \m/',
                                   }, {
                                       :user_description => 'Install Chef',
                                       :chef_server_url => @chef_server_url,
                                       :chef_version => "#{@chef_version}",
                                       :client_key => client_pem,
                                       :node_name => node_name,
                                       :install_sh_url => @install_sh_url,
                                       :chef_client_path => 'chef-client',
                                   })

      end

      def find_or_create_hanlon_model(machine_options)
        Hanlon::Api::Model.list.each do |model_uuid|
          m = Hanlon::Api::Model.find(model_uuid)
          puts "Comparing #{m.label} to #{machine_options[:model][:label]}..."
          if m.label == machine_options[:model][:label]
            return m
          end
        end

        Chef::Log.debug 'No valid model found, creating!'

        Hanlon::Api::Model.create({
                                      label: machine_options[:model][:label],
                                      template: machine_options[:model][:template],
                                      image_uuid: machine_options[:image_uuid]
                                  }, {
                                      hostname_prefix: machine_options[:model][:hostname_prefix],
                                      domainname: machine_options[:model][:domainname],
                                      root_password: machine_options[:model][:root_password]
                                  })
      end



    end
  end
end
