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

  test 'standard attribute assignment' do
    options = Asciidoctor::Cli::Options.parse!(%w"-a imagesdir=images,icons=1 my_input.asciidoc")

    assert_equal 'images', options.attributes[:imagesdir]
    assert_equal '1', options.attributes[:icons]
  end

  test 'multiple attribute arguments' do
    options = Asciidoctor::Cli::Options.parse!(%w"-a imagesdir=images -a icons=1 my_input.asciidoc")

    assert_equal 'images', options.attributes[:imagesdir]
    assert_equal '1', options.attributes[:icons]
  end

  test 'accept STDIN instead of only a file name' do
    pending "This hasn't been implemented yet in options"
  end
end
