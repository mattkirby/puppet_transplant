# encoding: UTF-8
require 'puppet_transplant/installer'

module Gem
  pre_install do |gem_installer|
    PuppetTransplant::Installer.pre_install(gem_installer)
  end
end
