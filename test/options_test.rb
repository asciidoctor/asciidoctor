require 'test_helper'
require 'asciidoctor/cli/options'

context 'Options' do
  test 'should return error code 0 when help flag is present' do
    redirect_streams do |stdout, stderr|
      exitval = Asciidoctor::Cli::Options.parse!(%w(-h))
      assert_equal 0, exitval
      assert_match(/^Usage:/, stdout.string)
    end
  end

  test 'should return error code 1 when invalid option present' do
    redirect_streams do |stdout, stderr|
      exitval = Asciidoctor::Cli::Options.parse!(%w(--foobar))
      assert_equal 1, exitval
      assert_equal 'asciidoctor: invalid option: --foobar', stderr.string.chomp
    end
  end

  test 'should return error code 1 when option has invalid argument' do
    redirect_streams do |stdout, stderr|
      exitval = Asciidoctor::Cli::Options.parse!(%w(-b foo input.ad))
      assert_equal 1, exitval
      assert_equal 'asciidoctor: invalid argument: -b foo', stderr.string.chomp
    end
  end

  test 'should return error code 1 when option is missing required argument' do
    redirect_streams do |stdout, stderr|
      exitval = Asciidoctor::Cli::Options.parse!(%w(-b))
      assert_equal 1, exitval
      assert_equal 'asciidoctor: option missing argument: -b', stderr.string.chomp
    end
  end

  test 'should emit warning when unparsed options remain' do
    redirect_streams do |stdout, stderr|
      options = Asciidoctor::Cli::Options.parse!(%w(-b docbook extra junk test/fixtures/sample.asciidoc))
      assert options.is_a? Hash
      assert_equal 'asciidoctor: WARNING: extra arguments detected (unparsed arguments: \'extra\', \'junk\')', stderr.string.chomp
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
    assert_equal '', options[:attributes]['icons']
  end

  test 'multiple attribute arguments' do
    options = Asciidoctor::Cli::Options.parse!(%w(-a imagesdir=images -a icons test/fixtures/sample.asciidoc))

    assert_equal 'images', options[:attributes]['imagesdir']
    assert_equal '', options[:attributes]['icons']
  end

end
