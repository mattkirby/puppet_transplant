# encoding: UTF-8
require 'puppet_transplant/installer'

module Gem
  ## We're no longer going the route of patching the binstub.  Instead, we're
  # going to override the default confdir and vardir in an effort to keep the
  # behavior of puppet as a library and puppet as an application consistent.
  # pre_install do |gem_installer|
  #   PuppetTransplant::Installer.pre_install(gem_installer)
  # end

  # Register a callback to override the default puppet confdir and vardir
  post_install do |gem_installer|
    PuppetTransplant::Installer.post_install(gem_installer)
  end
end
