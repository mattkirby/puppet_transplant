require 'pathname'
require 'rbconfig'
require 'rubygems/installer'

module PuppetTransplant
  ##
  # The Installer class contains all of the data and behavior required to
  # relocate Puppet's default system confdir and vardir settings.  The behavior
  # is intended to be implemented as a [rubygems
  # plugin](http://rubygems.rubyforge.org/rubygems-update/Gem.html#method-c-post_install),
  # called using something like the following example.
  #
  #     module Gem
  #       post_install do |gem_installer|
  #         PuppetTransplant::Installer.post_install(gem_installer)
  #       end
  #     end
  #
  # @author Jeff McCune <jeff@puppetlabs.com>
  class Installer
    ##
    # RelocationError instances are raised when modification of Puppet's
    # behavior fails for some reason.  The message should indicate why.
    class RelocationError < Exception; end

    ##
    # post_install takes a {Gem::Installer} instance expected to be passed from
    # a {Gem.post_install} callback and modifies an installed `puppet` gem to
    # use a relocated confdir and vardir.  This method does nothing if the
    # gem_installer instance is not processing puppet.
    #
    # @param [Gem::Installer] gem_installer The gem installer instance of the
    #   gem just installed, passed from the Gem.post_install callback.
    #
    # @return [Boolean] true if relocation succeeded, false if it did not
    #   succeed.
    def self.post_install(gem_installer)
      # Do nothing unless we're dealing with Puppet.
      return unless gem_installer.spec.name == 'puppet'
      # Perform the relocation
      installer = new(gem_installer)
      begin
        installer.relocate_puppet!
      rescue RelocationError => detail
        gem_installer.ui.alert_error "PuppetTransplant relocation failed: #{detail}"
        return false
      end
      # Let the user know what happened
      gem_installer.ui.debug "Transplanted confdir: #{installer.confdir}"
      gem_installer.ui.debug "Transplanted vardir:  #{installer.vardir}"
      return true
    end

    attr_reader :gem_installer

    ##
    # @param [Gem::Installer] gem_installer The gem installer instance
    #   typically passed from the plugin hook.
    def initialize(gem_installer)
      @gem_installer = gem_installer
    end

    ##
    # relocate_puppet! overrides the default confdir and vardir using one of
    # two methods.  First, if the version of Puppet being relocated provides
    # the Puppet::Util::RunMode.override_path method then the default path will
    # be overriden using this method.
    #
    # If the override_path API is not implemented in the version of Puppet
    # installed then the run_mode.rb file will be modified directly after
    # creating a backup at run_mode.rb.orig
    #
    # @return [Boolean] true if Puppet has been successfully relocated, false
    #   otherwise
    #
    # @api public
    def relocate_puppet!
      if puppet_override_api?
        rval = write_override_files
      else
        rval = modify_run_mode_in_place
      end
      !!rval
    end

    ##
    # modify_run_mode_in_place directly modifies Puppet's `run_mode.rb` file to
    # change the default system confdir and vardir.  This behavior is a
    # fallback mechanism in the event Puppet does not support the so-called
    # relocation API submitted at
    # https://github.com/puppetlabs/puppet/pull/2236
    #
    # @api private
    #
    # @raise [RelocationError] if the method could not perform the relocation.
    #   The reason will be included in the exception message.
    #
    # @see #relocate_puppet!
    # @see #puppet_override_api?
    #
    # @return [Boolean] true if `run_mode.rb` was successfully modified.
    def modify_run_mode_in_place
      # Locate the run_mode.rb file
      dir = gem_installer.dir
      files = spec.files

      if run_mode_file = files.find() {|p| p.match(/\/run_mode.rb$/)}
        run_mode_path = Pathname.new(File.join(dir, run_mode_file))
      else
        raise RelocationError, "Could not find run_mode.rb in the file list."
      end

      if not run_mode_path.readable?
        raise RelocationError, "#{run_mode_path} is not readable."
      end

      if not run_mode_path.writable?
        raise RelocationError, "#{run_mode_path} is not writable."
      end

      # This file is small enough to fit into memory.
      data = File.read(run_mode_path)

      # Modify the file in place for confdir
      if not data.gsub!(/\/etc\/puppet\b/, confdir)
        raise RelocationError, "Found no occurrences of /etc/puppet to replace."
      end
      # Modify the file in place for vardir
      if not data.gsub!(/\/var\/lib\/puppet\b/, vardir)
        raise RelocationError, "Found no occurrences of /var/lib/puppet to replace."
      end

      # Write the file back out to the system.
      File.open(run_mode_path, 'w') do |file|
        file.write(data)
      end
      return true
    end

    ##
    # write_override_files writes files to the filesystem using the
    # {Puppet::Util::RunMode.override_path) public API method to determine
    # whch files to write.  These files are intended to override the default
    # confdir and vardir for Puppet both as an application and as a library.
    # See {https://tickets.puppetlabs.com/browse/PUP-1406}
    #
    # @api private
    def write_override_files
      confdir_path = Puppet::Util::RunMode.override_path('confdir')
      vardir_path = Puppet::Util::RunMode.override_path('vardir')
      msg = "# Automatically overriden by the puppet_transplant gem"

      File.open(confdir_path, "w") do |f|
        f.puts(confdir)
        f.puts(msg)
      end

      File.open(vardir_path, "w") do |f|
        f.puts(vardir)
        f.puts(msg)
      end

      return true
    end

    ##
    # puppet_override_api? determines if the version of Puppet being processed
    # supports the {Puppet::Util::RunMode.override_path} API which makes it
    # easier to override the default confdir and vardir.
    #
    # @return [Boolean] if puppet supports the override_path API return true.
    #   if not return false.
    def puppet_override_api?
      require 'puppet/util/run_mode'
      Puppet::Util::RunMode.respond_to?(:override_path)
    end

    ##
    # org parses the filesystem path of the location of the ruby prefix path to
    # determine the organization name.  For example, if Ruby is installed with
    # a prefix of `/opt/operations` then this method will return `operations`.
    # With a Unix style path the second element from the root will be used.
    # With a Windows style path, the first directory following the drive
    # component will be used.  On windows `C:/operations` will return
    # `operations`.
    #
    # @api public
    #
    # @return [String] The org name parsed from the ruby prefix path or
    #   "unknown" if the parsing of the path did not succeed.
    def org
      return @org if @org
      path = Pathname.new(prefix)
      idx = is_windows ? 1 : 2
      @org = path.expand_path.to_s.split('/')[idx] || 'unknown'
    end

    ##
    # prefix returns the ruby prefix path of the currently running interpreter
    #
    # @api private
    #
    # @return [String] The prefix path of the ruby interpreter
    def prefix
      RbConfig::CONFIG['prefix']
    end

    ##
    # spec returns the {Gem::Specification} instance for the gem being
    # processed.
    #
    # @return [Gem::Specification] gem specification of the gem being installed.
    def spec
      gem_installer.spec
    end
    private :spec

    ##
    # is_windows returns true if the ruby interpreter is currently running on a
    # windows platform.
    def is_windows
      !!(RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/)
    end
    private :is_windows

    ##
    # confdir returns the path of the relocated default system confdir
    #
    # @api public
    #
    # @see #vardir
    #
    # @return [String] The fully qualified path of the relocated default system
    #   confdir.
    def confdir
      @confdir ||= "/opt/#{org}/etc/puppet"
    end

    ##
    # vardir returns the path of the relocated default system vardir
    #
    # @api public
    #
    # @see #confdir
    #
    # @return [String] The fully qualified path of the relocated default system
    #   vardir.
    def vardir
      @vardir ||= "/opt/#{org}/var/lib/puppet"
    end
  end
end
