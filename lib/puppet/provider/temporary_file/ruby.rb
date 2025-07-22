require 'open-uri'    # For downloading files from URIs
require 'fileutils'   # For file system operations like deleting
require 'puppet/util/temporary_file_tracker'

Puppet::Type.type(:temporary_file).provide(:default) do
  desc "Default provider for the `temporary_file` type.
    Handles downloading files from HTTP/HTTPS sources and managing their presence."

  # Automatically create `exists?`, `create`, `destroy` methods based on properties.
  # We will override them for custom logic.
  mk_resource_methods

  # Checks if the file exists at the specified path.
  def exists?
    #File.exist?(resource[:path])
    false
  end

  # Downloads the file from the source URI to the specified path.
  def create

    if required_by_other?
      Puppet.info("Temporary_file[#{resource[:name]}] is required, downloading from #{resource[:source]}")
      Puppet::Util::TemporaryFileTracker.add_temporary_file(resource[:path])
      
      begin
        # Use `URI.open` to handle HTTP/HTTPS downloads.
        open(resource[:source]) do |source_stream|
          # Open the destination file in binary write mode and copy content.
          File.open(resource[:path], 'wb') do |dest_file|
            IO.copy_stream(source_stream, dest_file)
          end
        end
        # Set appropriate default permissions for the downloaded file (e.g., readable by owner/group/others).
        File.chmod(0644, resource[:path])
        Puppet.debug("temporary_file: Successfully downloaded #{resource[:source]} to #{resource[:path]}")
      rescue OpenURI::HTTPError => e
        raise Puppet::Error, "temporary_file: Failed to download #{resource[:source]}: HTTP Error #{e.io.status[0]} - #{e.message}"
      rescue Errno::ENOENT => e
        raise Puppet::Error, "temporary_file: Could not create file at #{resource[:path]}: #{e.message}. Ensure parent directories exist (handled by `path` property)."
      rescue StandardError => e
        raise Puppet::Error, "temporary_file: An unexpected error occurred during download of #{resource[:source]}: #{e.message}"
      end
    else
      Puppet.info("Temporary_file[#{resource[:name]}] is not required, skipping download.")
    end

  
  end

  # Removes the file from the specified path.
  # This method is primarily called if `ensure => absent` is explicitly set on the temporary_file resource.
  # For automatic cleanup, the generated `file` resource in the 'cleanup' stage will handle deletion.
  def destroy
    Puppet.info("temporary_file: Removing temporary file #{resource[:path]}")
    if File.exist?(resource[:path])
      FileUtils.rm_f(resource[:path]) # Force remove, ignore if file doesn't exist (e.g., already cleaned up)
      Puppet.debug("temporary_file: Successfully removed #{resource[:path]}")
    else
      Puppet.debug("temporary_file: File #{resource[:path]} not found, nothing to remove.")
    end
  end


  # Check if this resource is required by another in the catalog
  def required_by_other?
    catalog = resource.catalog
    return false unless catalog

    # Get the current resource's reference
    resource_ref = resource.ref

    # Iterate through all resources in the catalog
    catalog.resources.each do |other_resource|
      next if other_resource == resource 
      next if other_resource.type.to_s.downcase == 'temporary_file_cleanup'
      next if other_resource.type.to_s.downcase == 'package' && other_resource[:ensure] == :absent
      next if other_resource.type.to_s.downcase == 'package' && other_resource[:ensure] == :present && other_resource.provider.query != nil 


      # Check if this resource is in the 'require' metaparameter of another
      requires = [other_resource[:require]].flatten.compact
      return true if requires.any? { |req| req.to_s == resource_ref }
    end

    false
  end
end