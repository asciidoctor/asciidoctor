require 'rubygems'
require 'ap'
require_relative 'lib/asciidoctor'

lines = File.readlines("test/fixtures/asciidoc_index.txt")
#lines = File.read("test/fixtures/asciidoc_index.txt")
doc = Asciidoctor::Document.new(lines)
doc.splain

foo = doc.render

puts foo

File.open("/tmp/noof.html", "w+") do |file|
  file.puts foo
end
