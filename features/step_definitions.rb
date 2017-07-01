# encoding: UTF-8
ASCIIDOCTOR_PROJECT_DIR = File.dirname File.dirname(__FILE__)
Dir.chdir ASCIIDOCTOR_PROJECT_DIR

if RUBY_VERSION < '1.9'
  require 'rubygems'
end

require 'simplecov' if ENV['COVERAGE'] == 'true'

require File.join(ASCIIDOCTOR_PROJECT_DIR, 'lib', 'asciidoctor')

require 'rspec/expectations'
require 'tilt'
require 'slim'

Given /the AsciiDoc source/ do |source|
  @source = source
end

When /it is converted to html/ do
  @output = Asciidoctor.convert @source
  #IO.write '/tmp/test.adoc', @source
  #@output = %x{asciidoc -f compat/asciidoc.conf -o - -s /tmp/test.adoc | XMLLINT_INDENT='' xmllint --format - | tail -n +2}.rstrip
  ##@output = %x{asciidoc -f compat/asciidoc.conf -o - -s /tmp/test.adoc}
end

When /it is converted to docbook/ do
  @output = Asciidoctor.convert @source, :backend => :docbook
end

Then /the result should (match|contain) the (HTML|XML) source/ do |matcher, format, expected|
  match_expectation = matcher == 'match' ? (eq expected) : (include expected)
  (expect @output).to match_expectation
end

Then /the result should (match|contain) the (HTML|XML) structure/ do |matcher, format, expected|
  result = @output
  if format == 'HTML'
    options = { :format => :html, :disable_escape => true, :sort_attrs => false }
  else # format == 'XML'
    options = { :format => :xhtml, :disable_escape => true, :sort_attrs => false }
    result = result.gsub '"/>', '" />' if result.include? '"/>'
  end
  result = Slim::Template.new(options) { result.each_line.map {|l| (l.start_with? '<') ? l : %(|#{l}) }.join }.render
  expected = Slim::Template.new(options) { expected }.render
  match_expectation = matcher == 'match' ? (eq expected) : (include expected)
  (expect result).to match_expectation
end
