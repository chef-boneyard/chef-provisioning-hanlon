require 'chef/provisioning/driver'
require 'chef/provisioning/machine/unix_machine'

require 'chef/provisioning/hanlon_driver/hanlon_broker'
require 'chef/provisioning/hanlon_driver/version'
require 'chef/provisioning/hanlon_driver/pxe_machine'
require 'chef/provisioning/hanlon_driver/recipe_dsl'
require 'chef/provisioning/transport/ssh'
require 'chef/provisioning/convergence_strategy/install_cached'

require 'yaml'
require 'hanlon/api'
#require 'pry'

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
        
        
        def find_or_create_hanlon_image(machine_options)
          # fail if image non-existant, we don't support create here yet
          if machine_options.image[:uuid]
            image = Hanlon::Api::Image.find(machine_options.image[:uuid])
            if image.nil?
              raise "Can't find hanlon image by uuid: #{machine_options.image[:uuid]}"
            end
          elsif machine_options.image[:os_name]
            image = Hanlon::Api::Image.find(machine_options.image[:os_name])
            if image.nil?
              raise "Can't find hanlon image by os_name: #{machine_options.image[:os_name]}"
            end
          else
            raise "A hanlon_image must be provided"
          end
          image
        end
        
        def find_or_create_hanlon_model(machine_options,image)
          model_options=machine_options[:model]
          match=Hanlon::Api::Model.filter('label',model_options[:label])
          
          return match.first if not match.empty?
          Chef::Log.debug "No model! Creating '#{model_options[:label]}'"
          
          Hanlon::Api::Model.create model_options.merge({image_uuid: image.uuid})
        end
        
        def find_or_create_hanlon_policy(machine_spec, machine_options, model) #, broker)
          policy_options=machine_options[:policy]
          policy_label = "#{policy_options[:label_prefix]} - #{machine_spec.name}"
          match=Hanlon::Api::Policy.filter('label',policy_label)
          return match.first if not match.empty?
          Chef::Log.debug "No policy! Creating '#{policy_label}'"
          policy = Hanlon::Api::Policy.create(policy_options.merge({
                                                            label: policy_label,
                                                            model_uuid: model.uuid,
                                                            enabled: true,
                                                            maximum: 1
                                                          })
                                             )
          begin
            binding.pry if policy.nil?
            result = policy.instance_variable_get(:@result)
            if result['code'] == 500
              raise result['description']
            end
          rescue Exception => e
            binding.pry
          end
          policy
        end
        
        def allocate_machine(action_handler, machine_spec, machine_options)
          # local vars to be set in action_handler.perform_action
          #return machine_spec if machine_spec.location['allocated_at']
          # need some logic not to allocate everytime
          image=model=policy=nil
          action_handler.perform_action "Looking for an image with uuid: #{machine_options.image[:uuid]}" do
            image=find_or_create_hanlon_image(machine_options)
          end
          Chef::Log.debug "Using image #{image.inspect}"
          binding.pry if not image
          
          action_handler.perform_action "Ensuring model #{machine_options.model[:label]} for our image" do
            model=find_or_create_hanlon_model(machine_options, image)
          end
          Chef::Log.debug "Using model #{model.inspect}"
          binding.pry if not model

          action_handler.perform_action "Requesting a node with tags:#{machine_options.policy[:tags]} binds to our model" do
            policy=find_or_create_hanlon_policy(machine_spec, machine_options, model)
          end
          binding.pry if not policy
          # binding.pry
          # need to check for @result.code
          #if ['500'].include? policy.instance_variable_get(:@result)['code']
          #  puts  policy.instance_variable_get(:@result)
          #  binding.pry
          #end
          Chef::Log.info "Using policy #{policy.inspect}"

          # https://github.com/net-ssh/net-ssh/blob/master/lib/net/ssh/config.rb#L144
          ssh_opts = {auth_methods: [],user_known_hosts_file:'/dev/null'}
          ssh_opts[:user] = 'core' if true # user
          if true # pubkey auth
            ssh_opts[:auth_methods] << 'publickey' 
            ssh_opts[:key_data] = []
            ['id_rsa'].each do |key_name|
              ssh_opts[:key_data] << get_private_key('coreos')
            end
          end
          
          # at this point we have requested a policy=>model=>image binding
          # with a max count of matching one node based ont the policy tags
          # match an available machine running hanlon mk, it will be bound
          # and start the provisioning process, for now without a broker
          # We will store the policy, because for now we don't know what
          # node we will be given
          # binding.pry
          machine_spec.location = {
            'driver_url' => driver_url,
            'driver_version' => Chef::Provisioning::HanlonDriver::VERSION,
            'allocated_at' => Time.now.utc.to_s,
            # not sure what host_node is for
            #'host_node' => action_handler.host_node,
            # not sure if we should just store uuid or the class
            # more info in class for sure
            'policy_uuid' => policy.uuid,
            'image_uuid' => image.uuid,
            'model_uuid' => model.uuid,
            ssh_opts: ssh_opts
            # should probably to_json on these
            #'policy' => policy,
            #'image' => image,
            #'model' => model,
          }
        end

        def ready_machine(action_handler, machine_spec, machine_options)
          # we should be retrieve the policy
          # and check to see if an active_model binding the policy to a node exists!
          # via the active_model we will be able to find the node, and it's ip address
          policy = policy_for(machine_spec, machine_options)
          binding.pry if not policy

          am_uuid=nil
          action_handler.perform_action "bind node with tags'#{policy.tags.join(',')}' / active_model bound to policy '#{policy.label}" do
            #Probably want some type of timeout
            until am_uuid
              am=Hanlon::Api::ActiveModel.filter(
                'root_policy', machine_spec.location['policy_uuid']).first
              if am
                am_uuid = am.uuid
              else
                sleep 5
              end
            end
          end
          machine_spec.location['active_model_uuid']=am_uuid


          node_uuid = nil
          action_handler.perform_action "Waiting for node to be written active model" do
            #Probably want some type of timeout
            until node_uuid
              am=Hanlon::Api::ActiveModel.find(am_uuid)
              if am.node
                node_uuid = am.node["@uuid"]
              else
                sleep 2
              end
            end
            am_uuid=am.uuid
            machine_spec.location['node_uuid']=node_uuid
          end

          # this is a quick hack, there is also a nice log
          # we could parse and update for each contact from
          # the node along the process
          # https://github.com/csc/Hanlon/wiki/active_model
          am=Hanlon::Api::ActiveModel.find(am_uuid)
          
          # last_state = current_state = am.model['@current_state']
          # until current_state == 'complete_no_broker'
          #   last_state = current_state = am.model['@current_state']
          #   action_handler.perform_action "Waiting for node to be leave #{last_state}" do
          #     Chef::Log.info("last: #{last_state} current: #{current_state}")
          #     until last_state != current_state
          #       am=Hanlon::Api::ActiveModel.find(am_uuid)
          #       # Chef::Log.info("checking last: #{last_state} current: #{current_state}")
          #       current_state = am.model['@current_state']
          #       sleep 2
          #     end
          #   end
          # end

          am_uuid=am.uuid
          machine_spec.location['node_uuid']=node_uuid
          # maybe we need to wait
          # we should also report active model state changes until we go from
          # init => complete_no_broker
          machine_spec.location[:ip_address]=am.node['@attributes_hash']['ipaddress']
          machine_for(machine_spec, machine_options)
        end


        def model_for(machine_spec, machine_options)
          if machine_spec.location['model_uuid']
            Hanlon::Api::Model.find(machine_spec.location['model_uuid'])
          end
        end

        def policy_for(machine_spec, machine_options)
          if machine_spec.location['policy_uuid']
            Hanlon::Api::Policy.find(machine_spec.location['policy_uuid'])
          end
        end

        def image_for(machine_spec, machine_options)
          if machine_spec.location['image_uuid']
            Hanlon::Api::Image.find(machine_spec.location['image_uuid'])
          end
        end

        def active_model_for(machine_spec, machine_options)
          if machine_spec.location['active_model_uuid']
            Hanlon::Api::ActiveModel.find(machine_spec.location['active_model_uuid'])
          end
        end

        def node_for(machine_spec, machine_options)
          if machine_spec.location['node_uuid']
            Hanlon::Api::Node.find(machine_spec.location['node_uuid'])
          end
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
          machine_for(machine_spec,machine_options)
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
          #Chef::Provisioning::HanlonDriver::PxeMachine.new(machine_spec,
          strat=Chef::Provisioning::ConvergenceStrategy::InstallCached.new(machine_options[:convergence_options],{})
          # binding.pry
          Chef::Provisioning::Machine::UnixMachine.new(machine_spec,
                                                       transport_for(machine_spec),
                                                       strat)
        end
        
        def transport_for(machine_spec)
          machine_spec.location[:ssh_opts] || machine_spec.location['ssh_opts'] || binding.pry
                             #machine_spec.location[:ssh_opts],

          ssh_opts = machine_spec.location[:ssh_opts] || machine_spec.location['ssh_opts']
          ssh_opts = ssh_opts.map{|k,v| {k.to_sym => v} }.reduce(&:merge)
          binding.pry
          @transport ||= begin
                           ssh_options = 
                             Chef::Provisioning::Transport::SSH.new(
                             # host
                             machine_spec.location[:ip_address]|| machine_spec.location['ip_address'],
                             # username
                             ssh_opts[:user] || ssh_opts['user'],
                             # ssh_options
                             # symbol vs string issue
                             ssh_opts,
                             #machine_spec.location[:ssh_opts] || machine_spec.location['ssh_opts'],
                             #machine_spec.location[:ssh_opts],
                             #.merge({
                             #                                         verbose: :debug
                              #                                      }),
                             # options
                             {
                               prefix: 'sudo ',
                               ssh_pty_enable: true,
                               ssh_gateway: nil
                             },
                             # global_config
                             config.merge({log_level: :debug})
                           )
                         end
          @transport || binding.pry
        end
        
        # aoeuaoeu
        #def convergence_strategy_for(machine_spec, machine_options)
        # binding.pry
        # I think the second bit is the chef_config
        #@converge_strategy ||= Chef::Provisioning::ConvergenceStrategy::InstallCached.
        #                           new(machine_options[:convergence_options],{})
        
        #@hanlon_broker_strategy ||= begin
        #Chef::Provisioning::ConvergenceStrategy::HanlonBroker.
        #    new(machine_options, machine_spec, config)
        #end
        #end
        
      end
    end
  end
end



