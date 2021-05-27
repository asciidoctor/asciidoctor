# frozen_string_literal: true

ASCIIDOCTOR_FEATURES_DIR = File.absolute_path __dir__
ASCIIDOCTOR_LIB_DIR = ENV['ASCIIDOCTOR_LIB_DIR'] || File.join(ASCIIDOCTOR_FEATURES_DIR, '../lib')

require 'simplecov' if ENV['COVERAGE'] == 'true'

require File.join ASCIIDOCTOR_LIB_DIR, 'asciidoctor'
Dir.chdir Asciidoctor::ROOT_DIR

require 'rspec/expectations'
require 'tilt'
require 'slim'

Given %r/the AsciiDoc source/ do |source|
  @source = source
end

When %r/it is converted to html/ do
  @output = Asciidoctor.convert @source
end

When %r/it is converted to docbook/ do
  @output = Asciidoctor.convert @source, backend: :docbook
end

Then %r/the result should (match|contain) the (HTML|XML) source/ do |matcher, _, expected|
  match_expectation = matcher == 'match' ? (eq expected) : (include expected)
  (expect @output).to match_expectation
end

Then %r/the result should (match|contain) the (HTML|XML) structure/ do |matcher, format, expected|
  result = @output
  if format == 'HTML'
    options = { format: :html, disable_escape: true, sort_attrs: false }
  else # format == 'XML'
    options = { format: :xhtml, disable_escape: true, sort_attrs: false }
    result = result.gsub '"/>', '" />' if result.include? '"/>'
  end
  result = Slim::Template.new(options) { result.each_line.map {|l| (l.start_with? '<') ? l : %(|#{l}) }.join }.render
  expected = Slim::Template.new(options) { expected }.render
  match_expectation = matcher == 'match' ? (eq expected) : (include expected)
  (expect result).to match_expectation
end
