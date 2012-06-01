require 'rubygems'

$:.unshift(File.dirname(__FILE__))
$:.unshift(File.join(File.dirname(__FILE__), '..', 'vendor'))

require 'emerson/errors'
require 'emerson/string'
require 'emerson/version'

require 'asciidoc'

module Emerson
end
