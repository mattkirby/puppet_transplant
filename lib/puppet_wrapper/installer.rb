module PuppetWrapper
  class Installer
    ##
    # process and install the wrapper script if the gem installer has just
    # installed the puppet gem.
    #
    # @param [Gem::Installer] gem_installer The gem installer instance of the
    #   gem just installed, passed from the Gem.post_install callback.
    def self.process(gem_installer)
      return unless gem_installer.spec.name == 'puppet'
      require 'pry'; binding.pry
      installer = new(gem_installer)
    end

    ##
    # @param [Gem::Installer] gem_installer The gem installer instance
    #   typically passed from the plugin hook.
    def initialize(gem_installer)
      @gem_installer = gem_installer
    end
  end
end
