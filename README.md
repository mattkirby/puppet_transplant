# PuppetTransplant

This gem is a [rubygems plugin](http://guides.rubygems.org/plugins/) that is
expected to be installed in the same gemset as Puppet.  The intent is to modify
the puppet gem to relocate the default confdir and vardir.  This behaviors
allows multiple versions of puppet to exist in different gemsets with distinct
default base directories.

The relocation directory is based on the Ruby PREFIX.  For example, if the
puppet gem is installed using a ruby with a prefix of `/opt/operations` then
`operations` will be used to construct a default system confdir of
`/etc/operations/puppet` and a default system vardir of
`/var/lib/operations/puppet`.  Similarly,
`/opt/crossfader/versions/ruby/1.9.3-p448` will result in
`/etc/crossfader/puppet` and `/var/lib/crossfader/puppet`.

The design of modifying the default confdir and vardir has been chosen to
support Puppet operating as a library in addition to Puppet operating as an
application.  This approach has the goal of keeping behavior consistent between
library based use cases and application based use cases as compared to a
wrapper script which sets --confdir and --vardir which introduces an
inconsistency between application and library use cases.

## Installation

Install this gem before installing Puppet to ensure puppet will be relocated
upon installation.

    $ gem install puppet_transplant

If you do not have permission to write to `$GEM_HOME`, try preserving your
environment in sudo:

    $ sudo -E gem install puppet_transplant

## Usage

Simply install the gem into the current gemset then install a puppet gem
afterwards.  For example:

    $ which gem
    /opt/operations/bin/gem

    $ sudo -E gem install puppet_transplant
    Fetching: puppet_transplant-0.0.2.gem (100%)
    Successfully installed puppet_transplant-0.0.2
    1 gem installed
    Installing ri documentation for puppet_transplant-0.0.2...
    Installing RDoc documentation for puppet_transplant-0.0.2...

    $ sudo -E gem install puppet --no-ri --no-rdoc
    Fetching: puppet-3.4.2.gem (100%)
    Transplanted confdir: /etc/operations/puppet
    Transplanted vardir:  /var/lib/operations/puppet
    Successfully installed puppet-3.4.2
    1 gem installed

    $ sudo -E puppet agent --configprint confdir
    /etc/operations/puppet
    $ sudo -E puppet agent --configprint vardir
    /var/lib/operations/puppet

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
