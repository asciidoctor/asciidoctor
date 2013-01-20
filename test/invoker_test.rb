require 'test_helper'
require "#{File.expand_path(File.dirname(__FILE__))}/../lib/asciidoctor/cli/options.rb"
require "#{File.expand_path(File.dirname(__FILE__))}/../lib/asciidoctor/cli/invoker.rb"
require 'pathname'

context 'Invoker' do
  test 'start asciidoctor' do
    #assert_nothing_raised do
      #assert_not_nil Asciidoctor::Cli::Invoker.new('test/fixtures/list_elements.asciidoc').invoke!
    #end
  end
end
