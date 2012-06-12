require 'rubygems'

$:.unshift(File.dirname(__FILE__))
$:.unshift(File.join(File.dirname(__FILE__), '..', 'vendor'))

require 'waldo/errors'
require 'waldo/string'
require 'waldo/version'

require 'waldo/asciidoc'

module Waldo
end
