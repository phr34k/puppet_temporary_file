require 'open-uri'    # For downloading files from URIs
require 'fileutils'   # For file system operations like deleting
require 'puppet/util/temporary_file_tracker'

Puppet::Type.type(:temporary_file_cleanup).provide(:default) do
  desc "Default provider for the `temporary_file` type.
    Handles downloading files from HTTP/HTTPS sources and managing their presence."

  # Automatically create `exists?`, `create`, `destroy` methods based on properties.
  # We will override them for custom logic.
  mk_resource_methods

  # Checks if the file exists at the specified path.
  def exists?
    false
  end

  # Downloads the file from the source URI to the specified path.
  def create    
    if Puppet::Util::TemporaryFileTracker.get_tracked_files.include?(resource[:path])
      Puppet.info("temporary_file_cleanup: **cleanup on isle 6** #{resource[:path]}")
  
      if File.exist?(resource[:path])
        FileUtils.rm_f(resource[:path]) # Force remove, ignore if file doesn't exist (e.g., already cleaned up)
        Puppet.debug("temporary_file_cleanup: Successfully removed #{resource}")
      else
        Puppet.debug("temporary_file_cleanup: File #{resource} not found, nothing to remove.")
      end

    end
  end

  # Removes the file from the specified path.
  # This method is primarily called if `ensure => absent` is explicitly set on the temporary_file resource.
  # For automatic cleanup, the generated `file` resource in the 'cleanup' stage will handle deletion.
  def destroy
    Puppet.info("temporary_file_cleanup: Removing temporary file #{resource[:path]}")
  end
end