# encoding: UTF-8
require 'puppet_transplant/installer'

module Gem
  # Register a callback to override the default puppet confdir and vardir
  post_install do |gem_installer|
    PuppetTransplant::Installer.post_install(gem_installer)
  end
end
