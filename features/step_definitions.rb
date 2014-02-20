require "#{File.dirname __FILE__}/../lib/asciidoctor"
require 'rspec/expectations'
require 'tilt'
require 'slim'

Given /the AsciiDoc source/ do |source|
  @source = source
end

When /it is converted to html/ do
  @output = Asciidoctor.convert @source
  #File.open('/tmp/test.adoc', 'w') {|f| f.write @source }
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
    options = {:format => :html5}
  when 'XML'
    options = {:format => :xhtml}
  else
    options = {}
  end
  slim_friendly_output = @output.lines.entries.map {|line|
    if line.start_with? '<'
      line
    else
      %(|#{line})
    end
  }.join
  Slim::Template.new(options) { slim_friendly_output }.render.should == Slim::Template.new(options) { expect }.render
end
