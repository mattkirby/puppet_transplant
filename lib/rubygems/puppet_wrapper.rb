# encoding: UTF-8
module Gem
  post_install do |gem_installer|
    require 'pry'; binding.pry
    # gem_installer.extend Something?
    gem_installer
  end
end
