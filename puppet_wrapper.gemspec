# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'puppet_wrapper/version'

Gem::Specification.new do |spec|
  spec.name          = "puppet_wrapper"
  spec.version       = PuppetWrapper::VERSION
  spec.authors       = ["Jeff McCune"]
  spec.email         = ["jeff@puppetlabs.com"]
  spec.description   = %q{Modify the puppet binstub to use /etc/operations/puppet and /var/lib/operations/puppet}
  spec.summary       = %q{Modify the puppet binstub to use /etc/operations/puppet and /var/lib/operations/puppet}
  spec.homepage      = ""
  spec.license       = "Apache 2.0"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
