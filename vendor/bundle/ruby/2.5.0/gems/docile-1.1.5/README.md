# Docile
[![Gem Version](https://badge.fury.io/rb/docile.png)](http://badge.fury.io/rb/docile)
[![Build Status](https://travis-ci.org/ms-ati/docile.png)](https://travis-ci.org/ms-ati/docile)
[![Dependency Status](https://gemnasium.com/ms-ati/docile.png)](https://gemnasium.com/ms-ati/docile)
[![Code Climate](https://codeclimate.com/github/ms-ati/docile.png)](https://codeclimate.com/github/ms-ati/docile)
[![Coverage Status](https://coveralls.io/repos/ms-ati/docile/badge.png)](https://coveralls.io/r/ms-ati/docile)
[![Inline docs](http://inch-ci.org/github/ms-ati/docile.png)](http://inch-ci.org/github/ms-ati/docile)
[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/ms-ati/docile/trend.png)](https://bitdeli.com/free "Bitdeli Badge")

Ruby makes it possible to create very expressive **Domain Specific
Languages**, or **DSL**'s for short. However, it requires some deep knowledge and
somewhat hairy meta-programming to get the interface just right.

"Docile" means *Ready to accept control or instruction; submissive* [[1]]

Instead of each Ruby project reinventing this wheel, let's make our Ruby DSL
coding a bit more docile...

[1]: http://www.google.com/search?q=docile+definition   "Google"

## Usage

### Basic

Let's say that we want to make a DSL for modifying Array objects.
Wouldn't it be great if we could just treat the methods of Array as a DSL?

```ruby
with_array([]) do
  push 1
  push 2
  pop
  push 3
end
#=> [1, 3]
```

No problem, just define the method `with_array` like this:

```ruby
def with_array(arr=[], &block)
  Docile.dsl_eval(arr, &block)
end
```

Easy!

### Advanced

Mutating (changing) an Array instance is fine, but what usually makes a good DSL is a [Builder Pattern][2].

For example, let's say you want a DSL to specify how you want to build a Pizza:

```ruby
@sauce_level = :extra

pizza do
  cheese
  pepperoni
  sauce @sauce_level
end
#=> #<Pizza:0x00001009dc398 @cheese=true, @pepperoni=true, @bacon=false, @sauce=:extra>
```

And let's say we have a PizzaBuilder, which builds a Pizza like this:

```ruby
Pizza = Struct.new(:cheese, :pepperoni, :bacon, :sauce)

class PizzaBuilder
  def cheese(v=true); @cheese = v; self; end
  def pepperoni(v=true); @pepperoni = v; self; end
  def bacon(v=true); @bacon = v; self; end
  def sauce(v=nil); @sauce = v; self; end
  def build
    Pizza.new(!!@cheese, !!@pepperoni, !!@bacon, @sauce)
  end
end

PizzaBuilder.new.cheese.pepperoni.sauce(:extra).build
#=> #<Pizza:0x00001009dc398 @cheese=true, @pepperoni=true, @bacon=false, @sauce=:extra>
```

Then implement your DSL like this:

``` ruby
def pizza(&block)
  Docile.dsl_eval(PizzaBuilder.new, &block).build
end
```

It's just that easy!

[2]: http://stackoverflow.com/questions/328496/when-would-you-use-the-builder-pattern  "Builder Pattern"

### Block parameters

Parameters can be passed to the DSL block.

Supposing you want to make some sort of cheap [Sinatra][3] knockoff:

```ruby
@last_request = nil
respond '/path' do |request|
  puts "Request received: #{request}"
  @last_request = request
end

def ride bike
  # Play with your new bike
end

respond '/new_bike' do |bike|
  ride(bike)
end
```

You'd put together a dispatcher something like this:

```ruby
require 'singleton'

class DispatchScope
  def a_method_you_can_call_from_inside_the_block
    :useful_huh?
  end
end

class MessageDispatch
  include Singleton

  def initialize
    @responders = {}
  end

  def add_responder path, &block
    @responders[path] = block
  end

  def dispatch path, request
    Docile.dsl_eval(DispatchScope.new, request, &@responders[path])
  end
end

def respond path, &handler
  MessageDispatch.instance.add_responder path, handler
end

def send_request path, request
  MessageDispatch.instance.dispatch path, request
end
```

[3]: http://www.sinatrarb.com "Sinatra"

### Functional-Style DSL Objects

Sometimes, you want to use an object as a DSL, but it doesn't quite fit the
[imperative](http://en.wikipedia.org/wiki/Imperative_programming) pattern shown
above.

Instead of methods like
[Array#push](http://www.ruby-doc.org/core-2.0/Array.html#method-i-push), which
modifies the object at hand, it has methods like
[String#reverse](http://www.ruby-doc.org/core-2.0/String.html#method-i-reverse),
which returns a new object without touching the original. Perhaps it's even
[frozen](http://www.ruby-doc.org/core-2.0/Object.html#method-i-freeze) in
order to enforce [immutability](http://en.wikipedia.org/wiki/Immutable_object).

Wouldn't it be great if we could just treat these methods as a DSL as well?

```ruby
s = "I'm immutable!".freeze

with_immutable_string(s) do
  reverse
  upcase
end
#=> "!ELBATUMMI M'I"

s
#=> "I'm immutable!"
```

No problem, just define the method `with_immutable_string` like this:

```ruby
def with_immutable_string(str="", &block)
  Docile.dsl_eval_immutable(str, &block)
end
```

All set!

## Features

  1.  Method lookup falls back from the DSL object to the block's context
  2.  Local variable lookup falls back from the DSL object to the block's
        context
  3.  Instance variables are from the block's context only
  4.  Nested DSL evaluation, correctly chaining method and variable handling
        from the inner to the outer DSL scopes
  5.  Alternatives for both imperative and functional styles of DSL objects

## Installation

``` bash
$ gem install docile
```

## Links
* [Source](https://github.com/ms-ati/docile)
* [Documentation](http://rubydoc.info/gems/docile)
* [Bug Tracker](https://github.com/ms-ati/docile/issues)

## Status

Works on [all ruby versions since 1.8.7](https://github.com/ms-ati/docile/blob/master/.travis.yml), or so Travis CI [tells us](https://travis-ci.org/ms-ati/docile).

Used by some pretty cool gems to implement their DSLs, notably including [SimpleCov](https://github.com/colszowka/simplecov). Keep an eye out for new gems using Docile at the [Ruby Toolbox](https://www.ruby-toolbox.com/projects/docile).

## Note on Patches/Pull Requests

  * Fork the project.
  * Setup your development environment with:
      `gem install bundler; bundle install`
  * Make your feature addition or bug fix.
  * Add tests for it. This is important so I don't break it in a future version
      unintentionally.
  * Commit, do not mess with rakefile, version, or history.
      (if you want to have your own version, that is fine but bump version in a
      commit by itself I can ignore when I pull)
  * Send me a pull request. Bonus points for topic branches.

## Copyright & License

Copyright (c) 2012-2014 Marc Siegel.

Licensed under the [MIT License](http://choosealicense.com/licenses/mit/), see [LICENSE](LICENSE) for details.


