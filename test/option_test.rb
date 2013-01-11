require 'test_helper'
require "#{File.expand_path(File.dirname(__FILE__))}/../lib/asciidoctor/cli/options.rb"

context 'Options' do
  test 'no input file option' do
    assert_raise(SystemExit) do
      Asciidoctor::Cli::Options.parse!(%w"")
    end
  end

  test 'basic argument assignment' do
    options = Asciidoctor::Cli::Options.parse!(%w"-v -s -d book my_input.asciidoc")

    assert_equal true, options.verbose
    assert_equal true, options.suppress_header_footer
    assert_equal :book, options.doctype
    assert_equal 'my_input.asciidoc', options.input_file
  end
end
