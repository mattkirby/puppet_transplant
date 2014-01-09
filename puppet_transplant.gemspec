# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'puppet_transplant/version'

Gem::Specification.new do |spec|
  spec.name          = "puppet_transplant"
  spec.version       = PuppetTransplant::VERSION
  spec.authors       = ["Jeff McCune"]
  spec.email         = ["jeff@puppetlabs.com"]
  spec.description   = %q{Relocate puppet to use a different default confdir and vardir}
  spec.summary       = %q{Relocate puppet to use a different default confdir and vardir}
  spec.homepage      = ""
  spec.license       = "Apache 2.0"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "yard"
  spec.add_development_dependency "redcarpet"
end
