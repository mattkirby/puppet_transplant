# PuppetTransplant

This gem is a [rubygems plugin](http://guides.rubygems.org/plugins/) that is
expected to be installed in the same gemset as Puppet.  The intent is to modify
the puppet gem to relocate the default confdir and vardir.  This behaviors
allows multiple versions of puppet to exist in different gemsets with distinct
default base directories.

The design of modifying the default confdir and vardir has been chosen to
support Puppet operating as a library in addition to Puppet operating as an
application.  This approach has the goal of keeping behavior consistent between
library based use cases and application based use cases as compared to a
wrapper script which sets --confdir and --vardir which introduces an
inconsistency between application and library use cases.

## Installation

Add this line to your application's Gemfile:

    gem 'puppet_transplant'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install puppet_transplant

## Usage

Simply install the gem into the current gemset.  If Puppet already exists in
this gemset then the default confdir and vardir will be modified to use
`/etc/operations/puppet` and `/var/lib/operations/puppet` respectively.

The relocation target directories are not currently configurable but this
should be a future improvement.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
