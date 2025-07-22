require 'puppet/util/checksums' # Not directly used for content, but a common include
require 'fileutils' # For Puppet::FileSystem.mkpath
require 'puppet/util/temporary_file_tracker' # We'll create this helper

Puppet::Type.newtype(:temporary_file) do
  @doc = "Manages the download and automatic cleanup of temporary files from a URI.
    The file is downloaded to a temporary location (or a specified path) and
    is automatically removed after the Puppet run's 'cleanup' stage has completed."

  # Ensure the resource can be created and removed (though removal is handled by a generated resource)
  ensurable do
    defaultvalues
    defaultto :present
  end

  autorequire(:class) do
    ['my_temp_files::autoloader']  # Class to require
  end

  newparam(:name, :namevar => true) do
    desc "The name of the temporary file resource. This is used as a unique identifier."
  end

  # Internal method to determine the consistent temporary file path.
  # This ensures the path is the same for the main resource and the cleanup resource.
  define_method(:temp_file_path) do
    # Use Puppet's vardir for persistent temporary files across runs,
    # ensuring unique names per resource instance.
    # The path is deterministic based on the resource name.
    File.join(Puppet[:vardir], 'temp_files', self[:name].to_s.gsub(/[^a-zA-Z0-9_.-]/, '_'))
  end

  newproperty(:path) do
    desc "The absolute path where the temporary file will be stored.
      Defaults to a unique path within Puppet's vardir (e.g., /opt/puppetlabs/puppet/cache/temp_files/<resource_name>)."
    defaultto do
      @resource.temp_file_path # Use the method defined above for consistency
    end
    # Ensure the parent directory exists before the provider attempts to write the file.
    munge do |value|
      dir = File.dirname(value)
      unless Puppet::FileSystem.directory?(dir)
        Puppet::FileSystem.mkpath(dir)
      end
      value
    end
  end

  newparam(:source) do
    desc "The URI (http or https) from which to download the file."
    validate do |value|
      unless value =~ %r{^https?://}
        raise ArgumentError, "Source must be an http or https URI."
      end
    end
  end

  # The `generate` method is called during catalog compilation.
  # It allows this resource to create additional resources in the catalog.
  def generate

    # Start with requiring the temporary_file resource itself
    dependencies = [self.ref] 

    # Iterate through ALL resources in the catalog *at this point in compilation*
    # to find those that explicitly require *this* temporary_file instance.
    self.catalog.resources.each do |other_resource|
      # Skip if it's the current temporary_file resource or another instance of it
      next if other_resource == self || other_resource.type == self.type

      # Check if other_resource has a 'require' metaparameter
      if other_resource[:require]
        # Ensure 'require' is an array of resource references for consistent checking
        requires_refs = [other_resource[:require]].flatten.compact.map(&:to_s)
        if requires_refs.include?(self.ref)
          dependencies << other_resource.ref
        end
      end
    end

    return [
      Puppet::Type.type(:temporary_file_cleanup).new(
        name: "cleanup_#{self[:name]}",
        path: "#{self[:path]}",
        require: dependencies.uniq 
      )
    ]
  end
end