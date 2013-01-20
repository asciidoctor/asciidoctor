require 'test_helper'
require 'asciidoctor/cli/options'

context 'Options' do
  test 'no input file option' do
    assert_raise(SystemExit) do
      Asciidoctor::Cli::Options.parse!(%w"")
    end
  end

  test 'basic argument assignment' do
    options = Asciidoctor::Cli::Options.parse!(%w"-v -s -d book my_input.asciidoc")

    assert_equal true, options[:verbose]
    assert_equal false, options[:header_footer]
    assert_equal 'book', options[:attributes]['doctype']
    assert_equal 'my_input.asciidoc', options[:input_file]
  end

  test 'standard attribute assignment' do
    options = Asciidoctor::Cli::Options.parse!(%w"-a imagesdir=images,icons=1 my_input.asciidoc")

    assert_equal 'images', options[:attributes]['imagesdir']
    assert_equal '1', options[:attributes]['icons']
  end

  test 'multiple attribute arguments' do
    options = Asciidoctor::Cli::Options.parse!(%w"-a imagesdir=images -a icons=1 my_input.asciidoc")

    assert_equal 'images', options[:attributes]['imagesdir']
    assert_equal '1', options[:attributes]['icons']
  end

  test 'accept STDIN instead of only a file name' do
    pending "This hasn't been implemented yet in options"
  end
end
