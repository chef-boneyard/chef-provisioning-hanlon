require 'chef_metal/machine'

module ChefMetalHanlon
  class PxeMachine < ChefMetal::Machine

    # PXE booted machines are a bit weird since we really have
    # no control over their booting or not. We have to treat them
    # as a delayed-boot box and do as much up-front prep work
    # as possible.
    def initialize(machine_spec, convergence_strategy)
      super(machine_spec)
      @convergence_strategy = convergence_strategy
    end

    # Sets up everything necessary for convergence to happen on the machine.
    # The node MUST be saved as part of this procedure.  Other than that,
    # nothing is guaranteed except that converge() will work when this is done.
    def setup_convergence(action_handler)
      Chef::Log.debug('PXE machine setup convergence')
      @convergence_strategy.setup_convergence(action_handler, self)
    end

    def converge(action_handler)
    end

    def cleanup_convergence(action_handler)
    end

    def execute(action_handler, command, options = {})
    end

    def execute_always(command, options = {})
    end

    def read_file(path)
    end

    def download_file(action_handler, path, local_path)
    end

    def write_file(action_handler, path, content)
    end

    def upload_file(action_handler, local_path, path)
    end

    def create_dir(action_handler, path)
    end

    # Delete file
    def delete_file(action_handler, path)
    end

    # Return true if directory, false/nil if not
    def is_directory?(path)
    end

    # Return true or false depending on whether file exists
    def file_exists?(path)
    end

    # Return true or false depending on whether remote file differs from local path or content
    def files_different?(path, local_path, content=nil)
    end

    # Set file attributes { mode, :owner, :group }
    def set_attributes(action_handler, path, attributes)
    end

    # Get file attributes { :mode, :owner, :group }
    def get_attributes(path)
    end

    # Ensure the given URL can be reached by the remote side (possibly by port forwarding)
    # Must return the URL that the remote side can use to reach the local_url
    def make_url_available_to_remote(local_url)
    end

    def disconnect
    end

    def detect_os(action_handler)
    end


  end
end
