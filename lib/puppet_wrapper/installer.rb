require 'pathname'
require 'rbconfig'
require 'rubygems/installer'

module PuppetWrapper
  class Installer
    ##
    # pre_install takes a {Gem::Installer} instance expected to be passed from
    # a Gem.pre_install callback and overrides the
    # {Gem::Installer#app_script_text} method if the puppet gem is about to be
    # installed.
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
    # 2. Otherwise modify ARGV to include `--confdir=/etc/#{org}` and
    # `--vardir=/var/lib/#{org}`
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
            ui.say "* PuppetWrapper produced #{bindir}/puppet"
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

    def app_script_text(bin_file_name)
      return <<-TEXT
#{shebang bin_file_name}
#
# This file was generated by PuppetWrapper in order to override the default
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
      @org = path.expand_path.to_s.split('/')[2] || 'unknown'
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
    # windows? returns true if the ruby interpreter is currently running on a
    # windows platform.
    def windows?
      !!(RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/)
    end
    private :windows?

    def confdir
      @confdir ||= "/etc/#{org}/puppet"
    end
    private :confdir

    def vardir
      @vardir ||= "/var/lib/#{org}/puppet"
    end
    private :vardir

    ##
    # bindir returns the bin directory where wrapper scripts will be written.
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
