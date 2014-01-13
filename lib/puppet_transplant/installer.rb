require 'pathname'
require 'rbconfig'
require 'rubygems/installer'

module PuppetTransplant
  class Installer
    class RelocationError < Exception; end

    ##
    # post_install takes a {Gem::Installer} instance expected to be passed from
    # a {Gem.post_install} callback and modifies an installed `puppet` gem to
    # use a relocated confdir and vardir.  This method does nothing if the
    # gem_installer instance is not processing puppet.
    #
    # @param [Gem::Installer] gem_installer The gem installer instance of the
    #   gem just installed, passed from the Gem.post_install callback.
    def self.post_install(gem_installer)
      # Do nothing unless we're dealing with Puppet.
      return unless gem_installer.spec.name == 'puppet'
      # Perform the relocation
      installer = new(gem_installer)
      installer.relocate_puppet!
      # Let the user know what happened
      gem_installer.ui.debug "Transplanted confdir: #{installer.confdir}"
      gem_installer.ui.debug "Transplanted vardir:  #{installer.vardir}"
    end

    ##
    # pre_install takes a {Gem::Installer} instance expected to be passed from
    # a Gem.pre_install callback and overrides the
    # {Gem::Installer#app_script_text} method if the puppet gem is about to be
    # installed.
    #
    # @deprecated in favor of {.post_install}
    #
    # @param [Gem::Installer] gem_installer The gem installer instance of the
    #   gem just installed, passed from the Gem.pre_install callback.
    def self.pre_install(gem_installer)
      return unless gem_installer.spec.name == 'puppet'
      installer = new(gem_installer)
      installer.modify_app_script_text!
    end

    attr_reader :gem_installer

    ##
    # @param [Gem::Installer] gem_installer The gem installer instance
    #   typically passed from the plugin hook.
    def initialize(gem_installer)
      @gem_installer = gem_installer
    end

    ##
    # modify_app_script_text! monkey patches the
    # {Gem::Installer#app_script_text}
    # method to implement the following behavior for the `puppet` binstub:
    #
    # 1. If `--confdir` or `--vardir` are specified via ARGV then use the
    # provided values.
    # 2. Otherwise modify ARGV to include `--confdir=/etc/#{org}/puppet` and
    # `--vardir=/var/lib/#{org}/puppet`
    #
    # @deprecated in favor of overriding the default and confdir in a manner
    #   that supports consistency between puppet as a library and puppet as an
    #   application.  Implementing a wrapper script that sets --confdir and
    #   --vardir creates inconsistent behavior between puppet as a library and
    #   puppet as an application.
    #
    # @see {#relocate_puppet!}
    #
    # @see #org
    #
    # @api private
    #
    # @return [String] the text of the modified app script.
    def modify_app_script_text!
      custom_app_script_text = method(:app_script_text)
      bindir  = bindir()
      confdir = confdir()
      vardir  = vardir()

      gem_installer.instance_eval do
        orig_app_script_text = method(:app_script_text)
        define_singleton_method(:app_script_text) do |bin_file_name|
          case bin_file_name
          when 'puppet'
            ui.say "***************************************************"
            ui.say "* PuppetTransplant produced #{bindir}/puppet"
            ui.say "*  confdir: #{confdir}"
            ui.say "*  vardir:  #{vardir}"
            ui.say "***************************************************"
            custom_app_script_text.call(bin_file_name)
          else
            orig_app_script_text.call(bin_file_name)
          end
        end
      end
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
        begin
          rval = modify_run_mode_in_place
        rescue RelocationError => detail
          gem_installer.ui.alert_error "Modification of run_mode.rb failed: #{detail}"
          return false
        end
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
      spec = gem_installer.spec

      if run_mode_file = spec.files.find() {|p| p.match(/\/run_mode.rb$/)}
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
    # @deprecated in favor of overriding the default and confdir in a manner
    #   that supports consistency between puppet as a library and puppet as an
    #   application.  Implementing a wrapper script that sets --confdir and
    #   --vardir creates inconsistent behavior between puppet as a library and
    #   puppet as an application.
    #
    # @see {#relocate_puppet!}
    #
    # @api private
    #
    # @return [String] the binstub contents
    def app_script_text(bin_file_name)
      return <<-TEXT
#{shebang bin_file_name}
#
# This file was generated by PuppetTransplant in order to override the default
# confdir and vardir in a generic way without patching.

require 'rubygems'

version = "#{Gem::Requirement.default}"

gem '#{spec.name}', version
load Gem.bin_path('#{spec.name}', '#{bin_file_name}', version)
TEXT
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

    def shebang(bin_file_name)
      gem_installer.shebang(bin_file_name)
    end
    private :shebang

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
      @confdir ||= "/etc/#{org}/puppet"
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
      @vardir ||= "/var/lib/#{org}/puppet"
    end

    ##
    # bindir returns the bin directory where binstub scripts will be written.
    def bindir
      bindir = gem_installer.bin_dir || Gem.bindir(gem_home)
    end
    private :bindir

    def gem_home
      gem_installer.gem_home
    end
    private :gem_home
  end
end
