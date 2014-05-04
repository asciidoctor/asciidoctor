# encoding: UTF-8
unless defined? ASCIIDOCTOR_PROJECT_DIR
  $: << File.dirname(__FILE__); $:.uniq!
  require 'test_helper'
end
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
      exitval = Asciidoctor::Cli::Options.parse!(%w(-d chapter input.ad)) # had to change for #320
      assert_equal 1, exitval
      assert_equal 'asciidoctor: invalid argument: -d chapter', stderr.string.chomp
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
      options = Asciidoctor::Cli::Options.parse!(%w(-b docbook - -))
      assert options.is_a? Hash
      assert_match(/asciidoctor: WARNING: extra arguments .*/, stderr.string.chomp)
    end
  end

  test 'basic argument assignment' do
    options = Asciidoctor::Cli::Options.parse!(%w(-v -s -d book test/fixtures/sample.asciidoc))

    assert_equal 2, options[:verbose]
    assert_equal false, options[:header_footer]
    assert_equal 'book', options[:attributes]['doctype']
    assert_equal 1, options[:input_files].size
    assert_equal 'test/fixtures/sample.asciidoc', options[:input_files][0]
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

  test 'should only split attribute key/value pairs on first equal sign' do
    options = Asciidoctor::Cli::Options.parse!(%w(-a name=value=value test/fixtures/sample.asciidoc))

    assert_equal 'value=value', options[:attributes]['name']
  end

  test 'should allow any backend to be specified' do
    options = Asciidoctor::Cli::Options.parse!(%w(-b my_custom_backend test/fixtures/sample.asciidoc))

    assert_equal 'my_custom_backend', options[:attributes]['backend']
  end

  test 'article doctype assignment' do
    options = Asciidoctor::Cli::Options.parse!(%w(-d article test/fixtures/sample.asciidoc))
    assert_equal 'article', options[:attributes]['doctype']
  end

  test 'book doctype assignment' do
    options = Asciidoctor::Cli::Options.parse!(%w(-d book test/fixtures/sample.asciidoc))
    assert_equal 'book', options[:attributes]['doctype']
  end

  test 'inline doctype assignment' do
    options = Asciidoctor::Cli::Options.parse!(%w(-d inline test/fixtures/sample.asciidoc))
    assert_equal 'inline', options[:attributes]['doctype']
  end

  test 'template engine assignment' do
    options = Asciidoctor::Cli::Options.parse!(%w(-E haml test/fixtures/sample.asciidoc))
    assert_equal 'haml', options[:template_engine]
  end

  test 'template directory assignment' do
    options = Asciidoctor::Cli::Options.parse!(%w(-T custom-backend test/fixtures/sample.asciidoc))
    assert_equal ['custom-backend'], options[:template_dirs]
  end

  test 'multiple template directory assignments' do
    options = Asciidoctor::Cli::Options.parse!(%w(-T custom-backend -T custom-backend-hacks test/fixtures/sample.asciidoc))
    assert_equal ['custom-backend', 'custom-backend-hacks'], options[:template_dirs]
  end

  test '-r option requires specified libraries' do
    options = Asciidoctor::Cli::Options.new
    redirect_streams do |stdout, stderr|
      exitval = options.parse! %w(-r foobar -r foobaz test/fixtures/sample.asciidoc)
      assert_match(%(asciidoctor: FAILED: 'foobar' could not be loaded), stderr.string)
      assert_equal 1, exitval
      assert_equal ['foobar', 'foobaz'], options[:requires]
    end
  end

  test '-I option appends directories to $LOAD_PATH' do
    options = Asciidoctor::Cli::Options.new
    old_load_path = $LOAD_PATH.dup
    begin
      exitval = options.parse! %w(-I foobar -I foobaz test/fixtures/sample.asciidoc)
      refute_equal 1, exitval
      assert_equal old_load_path.size + 2, $LOAD_PATH.size
      assert_equal File.expand_path('foobar'), $LOAD_PATH[0]
      assert_equal File.expand_path('foobaz'), $LOAD_PATH[1]
      assert_equal ['foobar', 'foobaz'], options[:load_paths]
    ensure
      ($LOAD_PATH.size - old_load_path.size).times { $LOAD_PATH.shift }
    end
  end

  test 'should set verbose to 2 when -v flag is specified' do
    options = Asciidoctor::Cli::Options.parse!(%w(-v test/fixtures/sample.asciidoc))
    assert_equal 2, options[:verbose]
  end

  test 'should set verbose to 0 when -q flag is specified' do
    options = Asciidoctor::Cli::Options.parse!(%w(-q test/fixtures/sample.asciidoc))
    assert_equal 0, options[:verbose]
  end

  test 'should set verbose to 2 when -v flag is specified after -q flag' do
    options = Asciidoctor::Cli::Options.parse!(%w(-q -v test/fixtures/sample.asciidoc))
    assert_equal 2, options[:verbose]
  end

  test 'should set verbose to 0 when -q flag is specified after -v flag' do
    options = Asciidoctor::Cli::Options.parse!(%w(-v -q test/fixtures/sample.asciidoc))
    assert_equal 0, options[:verbose]
  end

  test 'should enable timings when -t flag is specified' do
    options = Asciidoctor::Cli::Options.parse!(%w(-t test/fixtures/sample.asciidoc))
    assert_equal true, options[:timings]
  end

  test 'timings option is disable by default' do
    options = Asciidoctor::Cli::Options.parse!(%w(test/fixtures/sample.asciidoc))
    assert_equal false, options[:timings]
  end

end
