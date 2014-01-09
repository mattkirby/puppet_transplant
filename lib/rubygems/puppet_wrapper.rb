# encoding: UTF-8
require 'puppet_wrapper/installer'

module Gem
  pre_install do |gem_installer|
    PuppetWrapper::Installer.pre_install(gem_installer)
  end
end
