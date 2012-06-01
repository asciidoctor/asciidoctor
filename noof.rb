require 'rubygems'
require 'pp'
require 'lib/emerson'

lines = File.readlines("test/fixtures/asciidoc_index.txt")
doc = Asciidoc::Document.new(lines)
doc.splain
puts "*"*40
pp BaseTemplate.template_classes
puts "*"*40

foo = doc.render

puts foo

File.open("/tmp/noof.html", "w+") do |file|
  file.puts foo
end
