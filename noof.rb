require 'rubygems'
require 'pp'
require 'lib/emerson'

lines = File.readlines("test/fixtures/ascshort.txt")
doc = Asciidoc::Document.new(lines)
doc.splain
puts "*"*40
pp BaseTemplate.template_classes_nocamel
puts "*"*40

pp doc.render
