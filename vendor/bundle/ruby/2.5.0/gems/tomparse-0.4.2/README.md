# TomParse

[Website](http://github.com/rubyworks/tomparse) /
[Report Issue](http://github.com/rubyworks/tomparse/issues) /
[Source Code](http://github.com/rubyworks/tomparse) /
[Gem Page](http://rubygems.org/gems/tomparse)

[![Build Status](https://secure.travis-ci.org/rubyworks/tomparse.png)](http://travis-ci.org/rubyworks/tomparse)
[![Gem Version](https://badge.fury.io/rb/tomparse.png)](http://badge.fury.io/rb/tomparse)


## Description

TomParse is a TomDoc parser for Ruby. It provides no other functionality than
to take a code comment and parse it in to a convenient object-oriented
structure in accordance with the TomDoc standard. See [TomDoc](https://github.com/mojombo/tomdoc)
for more information about the TomDoc format.


## Instruction

### Installation

TomParse is available as a Ruby gem.

    $ gem install tomparse

### Usage

The primary interface is the `TomParse.parse` method. It will parse the
comment and return a `TomParse::TomDoc` instance.

    TomParse.parse(comment)  #=> TomParse::TomDoc

The comment string can have comment markers ('#') or not. The
parse will remove them if present. The resulting TomDoc object
then has a selection of methods that provide information from
the comment, such as `#arguments`, `#examples`, etc.

See the [API documention](http://rubydoc.info/gems/tomparse/frames)
for more details on this.

### Example

If you are unfamiliar with TomDoc, an example TomDoc comment for a method
looks something like this:

    # Duplicate some text an arbitrary number of times.
    #
    # text  - The String to be duplicated.
    # count - The Integer number of times to duplicate the text.
    #
    # Examples
    #   multiplex('Tom', 4)
    #   # => 'TomTomTomTom'
    #
    # Returns the duplicated String.
    def multiplex(text, count)
      text * count
    end

## Extra Features

Okay, we told a little white lie in the description. TomParse does take some
liberties with the specification to offer up some additional documentation
goodness.

### Arguments

The TomDoc specification is rather strict about how arguments are written --they
have to be the second section just after the description. TomParse offers a little
more flexability by allowing for an `Arguments` header to be used.

```ruby
  # Method to do fooey.
  #
  # Examples
  #   foo(name)
  #
  # Arguments
  #   name - Name of the fooey.
  #
  # Returns nothing.
  def foo(name)
    ...
```

We still recommend putting the arguments right after the desciption in most cases,
but there are times when its reads better to put them lower, such when using a
`Signatures` section (see below).

### Options

Ruby 2.0 finally introduces *keyword arguments* to the language. TomDoc's current
support of argument options, as a secondary argument list of a Hash argument,
doesn't take keyoword arguments into good account. To remedy this TomParse provides
and `Options` section, and it written just like one would an `Arguments` section.

```ruby
  # Method to do fooey.
  #
  # Options
  #   debug - Turn on debug mode? (default: false)
  #
  # Returns nothing.
  def foo(**options)
    ...
```

### Tags

One really nice new feature of TomParse is it's ability to recoginize sections
starting with a capitalized word followed by a colon and a space, as special *tags*.
Here is an example:

```ruby
  # Method to do something.
  #
  # TODO: This is a todo note.
  #
  # Returns nothing.
  def dosomething
    ...
```

When this is parsed, rather then lumping the TODO line in with the description,
the TomDoc instance will have a `tags` entry containing `['TODO', 'This is a todo note.']`.
It is important for consumer applications to recognize this. They can either just
add the tags back into the description when generating documentation, or handle
them  separately. But tags don't have to occur right after the description. They
can occur any place in the documentation.

### Signatures

TomParse does not support the Signature sections in exactly the same fashion as
the TomDoc specification describes. Rather then define dynamic methods, signatures
are used to specify alternate argument patterns, one signature per line.

```ruby
  # Method to do something.
  #
  # name - The name of the thing.
  # pattern - The pattern of the thing.
  #
  # Signatures
  #
  #   dosomething(name)
  #   dosomething(name=>pattern)
  #
  # Returns nothing.
  def dosomething(*args)
    ...
```

Technically the Signatures section can still be used to designate a dynamic method,
but as you can see by the above example, TomParse does not support the *field* list.
If needed just use the arguments list for these as well.

This choice was made, btw, because support for signatures as defined by the spec,
leads to very non-optimal code. It requires scanning every chunk of documentation
for a `Signature` section in order to determine how to treat it. What is needed
is a more universal syntax, that can be easily recognized by some clear identifier
at the top of a comment --and one that doesn't confuse dynamic method definitions
with the more traditional concept of method signatures.


## Resources

* [Website](http://rubyworks.github.com/tomparse)
* [Source Code](http://github.com/rubyworks/tomparse) (Github)
* [API Reference](http://rubydoc.info/gems/tomparse/frames")
* [Mailiing List](http://groups.google.com/group/rubyworks-mailinglist)
* [IRC Chat](http://chat.us.freenode.net/rubyworks)
* [Upstream Repo](http://github.com/rubyworks/tomparse/tomparse.git)


## Authors

<ul>
<li class="iauthor vcard">
  <span class="nickname">trans</span>
  <span>&lt;<a class="email" href="mailto:transfire@gmail.com">transfire@gmail.com</a>&gt;</span>
  <br/><a class="url" href="http://trans.gihub.com/">http://trans.github.com/</a>
</li>
</ul>


## Development 

### Requirements

* [Citron](http://rubyworks.github.com/citron) (testing)
* [AE](http://rubyworks.github.com/ae) (testing)
* [Fire](http://detroit.github.com/fire) (building)
* [Detroit](http://detroit.github.com/detroit) (building)


## Copyright & License

TomParse is copyrighted open-source software.

Copyright (c) 2012 [Rubyworks](http://rubyworks.github.com). All rights reserved.

TomParse is distributable under the terms of the [BSD-2-Clause]((http://www.spdx.org/licenses/BSD-2-Clause) license.

See LICENSE.txt for details.

