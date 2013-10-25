require "#{File.dirname __FILE__}/../lib/asciidoctor"
require 'rspec/expectations'
require 'tilt'
require 'slim'

Given /the AsciiDoc source/ do |source|
  #@document = Asciidoctor.load source
  @source = source
end

When /it is rendered using the html backend/ do
  @output = Asciidoctor.render @source
end

When /it is rendered using the docbook backend/ do
  @output = Asciidoctor.render @source, :backend => :docbook
end

Then /the output should match the (HTML|XML) source/ do |format, expect|
  @output.should == expect
end

Then /the output should match the (HTML|XML) structure/ do |format, expect|
  case format
  when 'HTML'
    options = {:format => :html5}
  when 'XML'
    options = {:format => :xhtml}
  else
    options = {}
  end
  Slim::Template.new(options) { @output }.render.should == Slim::Template.new(options) { expect }.render
end
