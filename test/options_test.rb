require 'test_helper'
require 'asciidoctor/cli/options'

context 'Options' do
  test 'should return error code 1 when invalid option present' do
    redirect_streams do |stdout, stderr|
      opts = Asciidoctor::Cli::Options.parse!(%w(--foobar))
      assert_equal 1, opts
      assert_equal 'invalid option: --foobar', stderr.string.chomp
    end
  end

  test 'basic argument assignment' do
    options = Asciidoctor::Cli::Options.parse!(%w(-v -s -d book test/fixtures/sample.asciidoc))

    assert_equal true, options[:verbose]
    assert_equal false, options[:header_footer]
    assert_equal 'book', options[:attributes]['doctype']
    assert_equal 'test/fixtures/sample.asciidoc', options[:input_file]
  end

  test 'standard attribute assignment' do
    options = Asciidoctor::Cli::Options.parse!(%w(-a imagesdir=images,icons test/fixtures/sample.asciidoc))

    assert_equal 'images', options[:attributes]['imagesdir']
    assert_equal 1, options[:attributes]['icons']
  end

  test 'multiple attribute arguments' do
    options = Asciidoctor::Cli::Options.parse!(%w(-a imagesdir=images -a icons test/fixtures/sample.asciidoc))

    assert_equal 'images', options[:attributes]['imagesdir']
    assert_equal 1, options[:attributes]['icons']
  end

end
