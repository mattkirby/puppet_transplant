# encoding: UTF-8
require 'puppet_wrapper/installer'

module Gem
  post_install do |gem_installer|
    PuppetWrapper::Installer.process(gem_installer)
  end
end
