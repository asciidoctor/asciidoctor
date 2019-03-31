# YARD TomDoc

[Website](http://rubyworks.github.com/yard-tomdoc) /
[Development](http://github.com/rubyworks/yard-tomdoc) /
[Issues](http://github.com/rubyworks/yard-tomdoc/issues)

[![Build Status](https://secure.travis-ci.org/rubyworks/yard-tomdoc.png)](http://travis-ci.org/rubyworks/yard-tomdoc)
[![Gem Version](https://badge.fury.io/rb/yard-tomdoc.png)](http://badge.fury.io/rb/yard-tomdoc)


## Description

Implements [TomDoc](http://tomdoc.org) syntax for YARD. 'Nuff said.


## Instruction

Since `yard-tomdoc` is a standard YARD plugin, utilize it with yard's
`--plugin` option.

    $ yard --plugin yard-tomdoc [...]


## Documentation

* API
  * YARD - [RubyDoc.info](http://rubydoc.info/gems/yard-tomdoc/frames)
  * Shomen - (out of date)
    [Rebecca](http://rubyworks.github.com/rebecca?doc=http://rubyworks.github.com/yard-tomdoc/docs/current.json) /
    [Hypervisor](http://rubyworks.github.com/hypervisor?doc=http://rubyworks.github.com/yard-tomdoc/docs/current.json) /
    [Rubyfaux](http://rubyworks.github.com/rubyfaux?doc=http://rubyworks.github.com/yard-tomdoc/docs/current.json)


## Limitations

Before you use yard-tomdoc you should read about the differences between YARD
and TomDoc syntax [here](http://gnuu.org/2010/05/12/whats-missing-from-tomdoc/).

Note that the YARD TomDoc plugin now supports a superset of TomDoc's syntax which
provides additional YARD functionality via *cap-tags*. For example using 
`Author: James Deam` in the documentation is equivalent to using `@author James Dean`
in regular YARD syntax. Support is limited but it opens up much more of the YARD
goodness to TomDoc users then the old blog post geiven above suggests.


## Acknowledgements

Huge thanks to Loren Segal, the creator of YARD and the original author of this
plugin. Without his patient assistance and coding genius, this library would not
have been possible.


## Licensing

YARD TomDoc is copyrighted open-source software.

Copyright (c) 2010 Rubyworks. All rights reserved.

YARD TomDoc can be modified and redistributed in accordance with the terms
of the **MIT** licsnse.

See the `LICENSE.txt` file for details.
