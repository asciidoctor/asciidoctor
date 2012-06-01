require 'rubygems'
require 'pp'
require 'lib/emerson'

lines = File.readlines("test/fixtures/asciidoc.txt")
doc = Asciidoc::Document.new(lines)
doc.splain
puts "*"*40
pp BaseTemplate.template_classes
puts "*"*40

pp doc.render
