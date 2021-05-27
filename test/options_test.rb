# frozen_string_literal: true
require_relative 'test_helper'
require File.join Asciidoctor::LIB_DIR, 'asciidoctor/cli/options'

context 'Options' do
  test 'should print usage and return error code 0 when help flag is present' do
    redirect_streams do |stdout, stderr|
      exitval = Asciidoctor::Cli::Options.parse!(%w(-h))
      assert_equal 0, exitval
      assert_match(/^Usage:/, stdout.string)
    end
  end

  test 'should show safe modes in severity order' do
    redirect_streams do |stdout, stderr|
      exitval = Asciidoctor::Cli::Options.parse!(%w(-h))
      assert_equal 0, exitval
      assert_match(/unsafe, safe, server, secure/, stdout.string)
    end
  end

  test 'should print usage and return error code 0 when help flag is unknown' do
    exitval, output = redirect_streams do |out, _|
      [Asciidoctor::Cli::Options.parse!(%w(-h unknown)), out.string]
    end
    assert_equal 0, exitval
    assert_match(/^Usage:/, output)
  end

  test 'should dump man page and return error code 0 when help topic is manpage' do
    exitval, output = redirect_streams do |out, _|
      [Asciidoctor::Cli::Options.parse!(%w(-h manpage)), out.string]
    end
    assert_equal 0, exitval
    assert_includes output, 'Manual: Asciidoctor Manual'
    assert_includes output, '.TH "ASCIIDOCTOR"'
  end

  test 'should an overview of the AsciiDoc syntax and return error code 0 when help topic is syntax' do
    exitval, output = redirect_streams do |out, _|
      [Asciidoctor::Cli::Options.parse!(%w(-h syntax)), out.string]
    end
    assert_equal 0, exitval
    assert_includes output, '= AsciiDoc Syntax'
    assert_includes output, '== Text Formatting'
  end

  test 'should print message and return error code 1 when manpage is not found' do
    old_manpage_path = ENV['ASCIIDOCTOR_MANPAGE_PATH']
    begin
      ENV['ASCIIDOCTOR_MANPAGE_PATH'] = (manpage_path = fixture_path 'no-such-file.1')
      redirect_streams do |out, stderr|
        exitval = Asciidoctor::Cli::Options.parse!(%w(-h manpage))
        assert_equal 1, exitval
        assert_equal %(asciidoctor: FAILED: manual page not found: #{manpage_path}), stderr.string.chomp
      end
    ensure
      if old_manpage_path
        ENV['ASCIIDOCTOR_MANPAGE_PATH'] = old_manpage_path
      else
        ENV.delete 'ASCIIDOCTOR_MANPAGE_PATH'
      end
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
      assert_kind_of Hash, options
      assert_match(/asciidoctor: WARNING: extra arguments .*/, stderr.string.chomp)
    end
  end

  test 'basic argument assignment' do
    options = Asciidoctor::Cli::Options.parse!(%w(-w -v -e -d book test/fixtures/sample.adoc))

    assert_equal 2, options[:verbose]
    assert_equal false, options[:standalone]
    assert_equal 'book', options[:attributes]['doctype']
    assert_equal 1, options[:input_files].size
    assert_equal 'test/fixtures/sample.adoc', options[:input_files][0]
  end

  test 'supports legacy option for no header footer' do
    options = Asciidoctor::Cli::Options.parse!(%w(-s test/fixtures/sample.adoc))

    assert_equal false, options[:standalone]
    assert_equal 1, options[:input_files].size
    assert_equal 'test/fixtures/sample.adoc', options[:input_files][0]
  end

  test 'standard attribute assignment' do
    options = Asciidoctor::Cli::Options.parse!(%w(-a docinfosubs=attributes,replacements -a icons test/fixtures/sample.adoc))

    assert_equal 'attributes,replacements', options[:attributes]['docinfosubs']
    assert_equal '', options[:attributes]['icons']
  end

  test 'multiple attribute arguments' do
    options = Asciidoctor::Cli::Options.parse!(%w(-a imagesdir=images -a icons test/fixtures/sample.adoc))

    assert_equal 'images', options[:attributes]['imagesdir']
    assert_equal '', options[:attributes]['icons']
  end

  test 'should only split attribute key/value pairs on first equal sign' do
    options = Asciidoctor::Cli::Options.parse!(%w(-a name=value=value test/fixtures/sample.adoc))

    assert_equal 'value=value', options[:attributes]['name']
  end

  test 'should not fail if value of attribute option is empty' do
    options = Asciidoctor::Cli::Options.parse!(['-a', '', 'test/fixtures/sample.adoc'])

    assert_nil options[:attributes]
  end

  test 'should not fail if value of attribute option is equal sign' do
    options = Asciidoctor::Cli::Options.parse!(['-a', '=', 'test/fixtures/sample.adoc'])

    assert_nil options[:attributes]
  end

  test 'should allow safe mode to be specified' do
    options = Asciidoctor::Cli::Options.parse!(%w(-S safe test/fixtures/sample.adoc))
    assert_equal Asciidoctor::SafeMode::SAFE, options[:safe]
  end

  test 'should allow any backend to be specified' do
    options = Asciidoctor::Cli::Options.parse!(%w(-b my_custom_backend test/fixtures/sample.adoc))

    assert_equal 'my_custom_backend', options[:attributes]['backend']
  end

  test 'article doctype assignment' do
    options = Asciidoctor::Cli::Options.parse!(%w(-d article test/fixtures/sample.adoc))
    assert_equal 'article', options[:attributes]['doctype']
  end

  test 'book doctype assignment' do
    options = Asciidoctor::Cli::Options.parse!(%w(-d book test/fixtures/sample.adoc))
    assert_equal 'book', options[:attributes]['doctype']
  end

  test 'inline doctype assignment' do
    options = Asciidoctor::Cli::Options.parse!(%w(-d inline test/fixtures/sample.adoc))
    assert_equal 'inline', options[:attributes]['doctype']
  end

  test 'template engine assignment' do
    options = Asciidoctor::Cli::Options.parse!(%w(-E haml test/fixtures/sample.adoc))
    assert_equal 'haml', options[:template_engine]
  end

  test 'template directory assignment' do
    options = Asciidoctor::Cli::Options.parse!(%w(-T custom-backend test/fixtures/sample.adoc))
    assert_equal ['custom-backend'], options[:template_dirs]
  end

  test 'multiple template directory assignments' do
    options = Asciidoctor::Cli::Options.parse!(%w(-T custom-backend -T custom-backend-hacks test/fixtures/sample.adoc))
    assert_equal ['custom-backend', 'custom-backend-hacks'], options[:template_dirs]
  end

  test 'multiple -r flags requires specified libraries' do
    options = Asciidoctor::Cli::Options.new
    redirect_streams do |stdout, stderr|
      exitval = options.parse! %w(-r foobar -r foobaz test/fixtures/sample.adoc)
      assert_match(%(asciidoctor: FAILED: 'foobar' could not be loaded), stderr.string)
      assert_equal 1, exitval
      assert_equal ['foobar', 'foobaz'], options[:requires]
    end
  end

  test '-r flag with multiple values requires specified libraries' do
    options = Asciidoctor::Cli::Options.new
    redirect_streams do |stdout, stderr|
      exitval = options.parse! %w(-r foobar,foobaz test/fixtures/sample.adoc)
      assert_match(%(asciidoctor: FAILED: 'foobar' could not be loaded), stderr.string)
      assert_equal 1, exitval
      assert_equal ['foobar', 'foobaz'], options[:requires]
    end
  end

  test '-I option appends paths to $LOAD_PATH' do
    options = Asciidoctor::Cli::Options.new
    old_load_path = $:.dup
    begin
      exitval = options.parse! %w(-I foobar -I foobaz test/fixtures/sample.adoc)
      refute_equal 1, exitval
      assert_equal old_load_path.size + 2, $:.size
      assert_equal File.expand_path('foobar'), $:[0]
      assert_equal File.expand_path('foobaz'), $:[1]
      assert_equal ['foobar', 'foobaz'], options[:load_paths]
    ensure
      ($:.size - old_load_path.size).times { $:.shift }
    end
  end

  test '-I option appends multiple paths to $LOAD_PATH' do
    options = Asciidoctor::Cli::Options.new
    old_load_path = $:.dup
    begin
      exitval = options.parse! %W(-I foobar#{File::PATH_SEPARATOR}foobaz test/fixtures/sample.adoc)
      refute_equal 1, exitval
      assert_equal old_load_path.size + 2, $:.size
      assert_equal File.expand_path('foobar'), $:[0]
      assert_equal File.expand_path('foobaz'), $:[1]
      assert_equal ['foobar', 'foobaz'], options[:load_paths]
    ensure
      ($:.size - old_load_path.size).times { $:.shift }
    end
  end

  test 'should set failure level to FATAL by default' do
    options = Asciidoctor::Cli::Options.parse! %w(test/fixtures/sample.adoc)
    assert_equal ::Logger::Severity::FATAL, options[:failure_level]
  end

  test 'should allow failure level to be set to WARN' do
    %w(w warn WARN warning WARNING).each do |val|
      options = Asciidoctor::Cli::Options.parse!(%W(--failure-level=#{val} test/fixtures/sample.adoc))
      assert_equal ::Logger::Severity::WARN, options[:failure_level]
    end
  end

  test 'should allow failure level to be set to ERROR' do
    %w(e err ERR error ERROR).each do |val|
      options = Asciidoctor::Cli::Options.parse!(%W(--failure-level=#{val} test/fixtures/sample.adoc))
      assert_equal ::Logger::Severity::ERROR, options[:failure_level]
    end
  end

  test 'should not allow failure level to be set to unknown value' do
    exit_code, messages = redirect_streams do |_, err|
      [(Asciidoctor::Cli::Options.parse! %w(--failure-level=foobar test/fixtures/sample.adoc)), err.string]
    end
    assert_equal 1, exit_code
    assert_includes messages, 'invalid argument: --failure-level=foobar'
  end

  test 'should set verbose to 2 when -v flag is specified' do
    options = Asciidoctor::Cli::Options.parse!(%w(-v test/fixtures/sample.adoc))
    assert_equal 2, options[:verbose]
  end

  test 'should set verbose to 0 when -q flag is specified' do
    options = Asciidoctor::Cli::Options.parse!(%w(-q test/fixtures/sample.adoc))
    assert_equal 0, options[:verbose]
  end

  test 'should set verbose to 2 when -v flag is specified after -q flag' do
    options = Asciidoctor::Cli::Options.parse!(%w(-q -v test/fixtures/sample.adoc))
    assert_equal 2, options[:verbose]
  end

  test 'should set verbose to 0 when -q flag is specified after -v flag' do
    options = Asciidoctor::Cli::Options.parse!(%w(-v -q test/fixtures/sample.adoc))
    assert_equal 0, options[:verbose]
  end

  test 'should enable warnings when -w flag is specified' do
    options = Asciidoctor::Cli::Options.parse!(%w(-w test/fixtures/sample.adoc))
    assert options[:warnings]
  end

  test 'should enable timings when -t flag is specified' do
    options = Asciidoctor::Cli::Options.parse!(%w(-t test/fixtures/sample.adoc))
    assert_equal true, options[:timings]
  end

  test 'timings option is disable by default' do
    options = Asciidoctor::Cli::Options.parse!(%w(test/fixtures/sample.adoc))
    assert_equal false, options[:timings]
  end

end
