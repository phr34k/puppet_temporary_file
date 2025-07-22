module Puppet::Util::TemporaryFileTracker
  # Use a class instance variable to store the list across resource instances
  @tracked_files = []
  @mutex = Mutex.new # Use a mutex for thread safety if Puppet ever uses multiple threads for resource application

  def self.add_temporary_file(path)
    @mutex.synchronize do
      @tracked_files << path unless @tracked_files.include?(path)
      Puppet.debug("TemporaryFileTracker: Added '#{path}'. Current list: #{@tracked_files}")
    end
  end

  def self.remove_temporary_file(path)
    @mutex.synchronize do
      @tracked_files.delete(path)
      Puppet.debug("TemporaryFileTracker: Removed '#{path}'. Current list: #{@tracked_files}")
    end
  end

  def self.get_tracked_files
    @mutex.synchronize do
      @tracked_files.dup # Return a duplicate to prevent external modification
    end
  end

  # You might want a way to clear it at the end of a run or per-catalog
  # if you're doing something very advanced, but usually the process
  # lifecycle handles this.
end