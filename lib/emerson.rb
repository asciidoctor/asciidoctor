require 'rubygems'

$:.unshift(File.dirname(__FILE__))
$:.unshift(File.join(File.dirname(__FILE__), '..', 'vendor'))

require 'emerson/version'
require 'emerson/errors'

require 'asciidoc'

module Emerson
end
