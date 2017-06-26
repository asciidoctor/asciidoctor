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

Then /the result should match the (HTML|XML) source/ do |format, expect|
  @output.should == expect
end

Then /the result should match the (HTML|XML) structure/ do |format, expect|
  case format
  when 'HTML'
    options = { :format => :html, :disable_escape => true, :sort_attrs => false }
  when 'XML'
    options = { :format => :xhtml, :disable_escape => true, :sort_attrs => false }
  else
    options = {}
  end
  slim_friendly_output = @output.each_line.map {|line|
    if line.start_with? '<'
      line
    else
      %(|#{line})
    end
  }.join
  Slim::Template.new(options) { slim_friendly_output }.render.should == Slim::Template.new(options) { expect }.render
end
