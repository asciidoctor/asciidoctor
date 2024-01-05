# frozen_string_literal: false

require_relative 'test_helper'
require File.join Asciidoctor::LIB_DIR, 'asciidoctor/cli'

context 'Invoker' do
  test 'should allow Options to be passed as first argument of constructor' do
    opts = Asciidoctor::Cli::Options.new attributes: { 'toc' => '' }, doctype: 'book', sourcemap: true
    invoker = Asciidoctor::Cli::Invoker.new opts
    assert_same invoker.options, opts
  end

  test 'should allow options Hash to be passed as first argument of constructor' do
    opts = { attributes: { 'toc' => '' }, doctype: 'book', sourcemap: true }
    invoker = Asciidoctor::Cli::Invoker.new opts
    resolved_opts = invoker.options
    assert_equal opts[:attributes], resolved_opts[:attributes]
    assert_equal 'book', resolved_opts[:attributes]['doctype']
    assert resolved_opts[:sourcemap]
  end

  test 'should parse options from array passed as first argument of constructor' do
    input_file = fixture_path 'basic.adoc'
    invoker = Asciidoctor::Cli::Invoker.new ['-s', input_file]
    resolved_options = invoker.options
    refute resolved_options[:standalone]
    assert_equal [input_file], resolved_options[:input_files]
  end

  test 'should parse options from multiple arguments passed to constructor' do
    input_file = fixture_path 'basic.adoc'
    invoker = Asciidoctor::Cli::Invoker.new '-s', input_file
    resolved_options = invoker.options
    refute resolved_options[:standalone]
    assert_equal [input_file], resolved_options[:input_files]
  end

  test 'should parse source and convert to html5 article by default' do
    invoker = nil
    output = nil
    redirect_streams do |out|
      invoker = invoke_cli %w(-o -)
      output = out.string
    end
    refute_nil invoker
    doc = invoker.document
    refute_nil doc
    assert_equal 'Document Title', doc.doctitle
    assert_equal 'Doc Writer', doc.attr('author')
    assert_equal 'html5', doc.attr('backend')
    assert_equal '.html', doc.attr('outfilesuffix')
    assert_equal 'article', doc.attr('doctype')
    assert doc.blocks?
    assert_equal :preamble, doc.blocks.first.context
    refute_empty output
    assert_xpath '/html', output, 1
    assert_xpath '/html/head', output, 1
    assert_xpath '/html/body', output, 1
    assert_xpath '/html/head/title[text() = "Document Title"]', output, 1
    assert_xpath '/html/body[@class="article"]/*[@id="header"]/h1[text() = "Document Title"]', output, 1
  end

  test 'should set implicit doc info attributes' do
    sample_filepath = fixture_path 'sample.adoc'
    sample_filedir = fixturedir
    invoker = invoke_cli_to_buffer %w(-o /dev/null), sample_filepath
    doc = invoker.document
    assert_equal 'sample', doc.attr('docname')
    assert_equal sample_filepath, doc.attr('docfile')
    assert_equal sample_filedir, doc.attr('docdir')
    assert doc.attr?('docdate')
    assert doc.attr?('docyear')
    assert doc.attr?('doctime')
    assert doc.attr?('docdatetime')
    assert_empty invoker.read_output
  end

  test 'should allow docdate and doctime to be overridden' do
    sample_filepath = fixture_path 'sample.adoc'
    invoker = invoke_cli_to_buffer %w(-o /dev/null -a docdate=2015-01-01 -a doctime=10:00:00-0700), sample_filepath
    doc = invoker.document
    assert doc.attr?('docdate', '2015-01-01')
    assert doc.attr?('docyear', '2015')
    assert doc.attr?('doctime', '10:00:00-0700')
    assert doc.attr?('docdatetime', '2015-01-01 10:00:00-0700')
  end

  test 'should accept document from stdin and write to stdout' do
    invoker = invoke_cli_to_buffer(%w(-e), '-') { 'content' }
    doc = invoker.document
    refute doc.attr?('docname')
    refute doc.attr?('docfile')
    assert_equal Dir.pwd, doc.attr('docdir')
    assert_equal doc.attr('docdate'), doc.attr('localdate')
    assert_equal doc.attr('docyear'), doc.attr('localyear')
    assert_equal doc.attr('doctime'), doc.attr('localtime')
    assert_equal doc.attr('docdatetime'), doc.attr('localdatetime')
    refute doc.attr?('outfile')
    output = invoker.read_output
    refute_empty output
    assert_xpath '/*[@class="paragraph"]/p[text()="content"]', output, 1
  end

  test 'should not fail to rewind input if reading document from stdin' do
    begin
      old_stdin = $stdin
      $stdin = StringIO.new 'paragraph'
      invoker = invoke_cli_to_buffer %w(-e), '-'
      assert_equal 0, invoker.code
      assert_equal 1, invoker.document.blocks.size
    ensure
      $stdin = old_stdin
    end
  end

  test 'should accept document from stdin and write to output file' do
    sample_outpath = fixture_path 'sample-output.html'
    begin
      invoker = invoke_cli(%W(-e -o #{sample_outpath}), '-') { 'content' }
      doc = invoker.document
      refute doc.attr?('docname')
      refute doc.attr?('docfile')
      assert_equal Dir.pwd, doc.attr('docdir')
      assert_equal doc.attr('docdate'), doc.attr('localdate')
      assert_equal doc.attr('docyear'), doc.attr('localyear')
      assert_equal doc.attr('doctime'), doc.attr('localtime')
      assert_equal doc.attr('docdatetime'), doc.attr('localdatetime')
      assert doc.attr?('outfile')
      assert_equal sample_outpath, doc.attr('outfile')
      assert_path_exists sample_outpath
    ensure
      FileUtils.rm_f sample_outpath
    end
  end

  test 'should fail if input file matches resolved output file' do
    invoker = invoke_cli_to_buffer %w(-a outfilesuffix=.adoc), 'sample.adoc'
    assert_match(/input file and output file cannot be the same/, invoker.read_error)
  end

  test 'should fail if input file matches specified output file' do
    sample_outpath = fixture_path 'sample.adoc'
    invoker = invoke_cli_to_buffer %W(-o #{sample_outpath}), 'sample.adoc'
    assert_match(/input file and output file cannot be the same/, invoker.read_error)
  end

  test 'should accept input from named pipe and output to stdout', unless: windows? do
    sample_inpath = fixture_path 'sample-pipe.adoc'
    begin
      %x(mkfifo #{sample_inpath})
      write_thread = Thread.new do
        File.write sample_inpath, 'pipe content'
      end
      invoker = invoke_cli_to_buffer %w(-a stylesheet!), sample_inpath
      result = invoker.read_output
      assert_match(/pipe content/, result)
      write_thread.join
    ensure
      FileUtils.rm_f sample_inpath
    end
  end

  test 'should allow docdir to be specified when input is a string' do
    expected_docdir = fixturedir
    invoker = invoke_cli_to_buffer(%w(-e --base-dir test/fixtures -o /dev/null), '-') { 'content' }
    doc = invoker.document
    assert_equal expected_docdir, doc.attr('docdir')
    assert_equal expected_docdir, doc.base_dir
  end

  test 'should display version and exit' do
    expected = %(Asciidoctor #{Asciidoctor::VERSION} [https://asciidoctor.org]\nRuntime Environment (#{RUBY_DESCRIPTION}))
    ['--version', '-V'].each do |switch|
      actual = nil
      redirect_streams do |out|
        invoke_cli [switch]
        actual = out.string.rstrip
      end
      refute_nil actual
      assert actual.start_with?(expected), %(Expected to print version when using #{switch} switch)
    end
  end

  test 'should print warnings to stderr by default' do
    input = <<~'EOS'
    2. second
    3. third
    EOS
    warnings = nil
    redirect_streams do |_, err|
      invoke_cli_to_buffer(%w(-o /dev/null), '-') { input }
      warnings = err.string
    end
    assert_match(/WARNING/, warnings)
  end

  test 'should change level on logger when --log-level is specified' do
    input = <<~'EOS'
    skip to <<install>>

    . download
    . install[[install]]
    . run
    EOS
    output = nil
    redirect_streams do |_, err|
      invoke_cli(%w(--log-level info), '-') { input }
      output = err.string
    end
    assert_equal 'asciidoctor: INFO: possible invalid reference: install', output.chomp
  end

  test 'should not log when --log-level and -q are both specified' do
    input = <<~'EOS'
    skip to <<install>>

    . download
    . install[[install]]
    . run
    EOS
    output = nil
    redirect_streams do |_, err|
      invoke_cli(%w(--log-level info -q), '-') { input }
      output = err.string
    end
    assert_empty output
  end

  test 'should use specified log level when --log-level and -v are both specified' do
    input = <<~'EOS'
    skip to <<install>>

    . download
    . install[[install]]
    . run
    EOS
    output = nil
    redirect_streams do |_, err|
      invoke_cli(%w(--log-level warn -v), '-') { input }
      output = err.string
    end
    assert_empty output
  end

  test 'should enable script warnings if -w flag is specified' do
    old_verbose, $VERBOSE = $VERBOSE, false
    begin
      warnings = nil
      redirect_streams do |_, err|
        invoke_cli_to_buffer %w(-w -o /dev/null), '-' do
          A_CONST = 10
          A_CONST = 20
        end
        warnings = err.string
      end
      assert_equal false, $VERBOSE # rubocop:disable Minitest/RefuteFalse
      refute_empty warnings
    ensure
      $VERBOSE = old_verbose
    end
  end

  test 'should silence warnings if -q flag is specified' do
    input = <<~'EOS'
    2. second
    3. third
    EOS
    warnings = nil
    redirect_streams do |_, err|
      invoke_cli_to_buffer(%w(-q -o /dev/null), '-') { input }
      warnings = err.string
    end
    assert_equal '', warnings
  end

  test 'should not fail to check log level when -q flag is specified' do
    input = <<~'EOS'
    skip to <<install>>

    . download
    . install[[install]]
    . run
    EOS
    begin
      old_stderr, $stderr = $stderr, StringIO.new
      old_stdout, $stdout = $stdout, StringIO.new
      invoker = invoke_cli(%w(-q), '-') { input }
      assert_equal 0, invoker.code
    ensure
      $stderr = old_stderr
      $stdout = old_stdout
    end
  end

  test 'should return non-zero exit code if failure level is reached' do
    input = <<~'EOS'
    2. second
    3. third
    EOS
    exit_code, messages = redirect_streams do |_, err|
      [invoke_cli(%w(-q --failure-level=WARN -o /dev/null), '-') { input }.code, err.string]
    end
    assert_equal 1, exit_code
    assert_empty messages
  end

  test 'should report usage if no input file given' do
    redirect_streams do |_, err|
      invoke_cli [], nil
      assert_match(/Usage:/, err.string)
    end
  end

  test 'should report error if input file does not exist' do
    redirect_streams do |_, err|
      invoker = invoke_cli [], 'missing_file.adoc'
      assert_match(/input file .* is missing/, err.string)
      assert_equal 1, invoker.code
    end
  end

  test 'should suggest --trace option if not present when program raises error' do
    redirect_streams do |_, err|
      sample_filepath = fixture_path 'sample.adoc'
      invoker = invoke_cli ['-r', 'no-such-module'], sample_filepath
      assert_match(/'no-such-module' could not be loaded\n *Use --trace to show backtrace/, err.string)
      assert_equal 1, invoker.code
    end
  end

  test 'should raise error when --trace option is specified and program raises error' do
    sample_filepath = fixture_path 'sample.adoc'
    assert_raises LoadError do
      invoke_cli ['--trace', '-r', 'no-such-module'], sample_filepath
    end
  end

  test 'should show backtrace when --trace option is specified and program raises error', unless: (jruby? && windows?) do
    result = run_command(asciidoctor_cmd, '-r', 'no-such-module', '--trace', (fixture_path 'basic.adoc')) {|out| out.read }
    if jruby?
      assert_match(/LoadError: no such file to load -- no-such-module\n *require at /, result)
    else
      assert_match(/cannot load such file -- no-such-module \(LoadError\)\n\tfrom /, result)
    end
  end

  test 'should treat extra arguments as files' do
    redirect_streams do |_, err|
      invoker = invoke_cli %w(-o /dev/null extra arguments sample.adoc), nil
      assert_match(/input file .* is missing/, err.string)
      assert_equal 1, invoker.code
    end
  end

  test 'should output to file name based on input file name' do
    sample_outpath = fixture_path 'sample.html'
    begin
      invoker = invoke_cli
      doc = invoker.document
      assert_equal sample_outpath, doc.attr('outfile')
      assert_path_exists sample_outpath
      output = File.read sample_outpath, mode: Asciidoctor::FILE_READ_MODE
      refute_empty output
      assert_xpath '/html', output, 1
      assert_xpath '/html/head', output, 1
      assert_xpath '/html/body', output, 1
      assert_xpath '/html/head/title[text() = "Document Title"]', output, 1
      assert_xpath '/html/body/*[@id="header"]/h1[text() = "Document Title"]', output, 1
    ensure
      FileUtils.rm_f sample_outpath
    end
  end

  test 'should output to file in destination directory if set' do
    destination_path = File.join testdir, 'test_output'
    sample_outpath = File.join destination_path, 'sample.html'
    begin
      FileUtils.mkdir_p destination_path
      # QUESTION should -D be relative to working directory or source directory?
      invoker = invoke_cli %w(-D test/test_output)
      #invoker = invoke_cli %w(-D ../../test/test_output)
      doc = invoker.document
      assert_equal sample_outpath, doc.attr('outfile')
      assert_path_exists sample_outpath
    ensure
      FileUtils.rm_f sample_outpath
      FileUtils.rmdir destination_path
    end
  end

  test 'should preserve directory structure in destination directory if source directory is set' do
    sample_inpath = 'subdir/index.adoc'
    destination_path = 'test_output'
    destination_subdir_path = File.join destination_path, 'subdir'
    sample_outpath = File.join destination_subdir_path, 'index.html'
    begin
      FileUtils.mkdir_p destination_path
      invoke_cli %W(-D #{destination_path} -R test/fixtures), sample_inpath
      assert File.directory?(destination_subdir_path)
      assert_path_exists sample_outpath
    ensure
      FileUtils.rm_f sample_outpath
      FileUtils.rmdir destination_subdir_path
      FileUtils.rmdir destination_path
    end
  end

  test 'should output to file specified' do
    sample_outpath = fixture_path 'sample-output.html'
    begin
      invoker = invoke_cli %W(-o #{sample_outpath})
      doc = invoker.document
      assert_equal sample_outpath, doc.attr('outfile')
      assert_path_exists sample_outpath
    ensure
      FileUtils.rm_f sample_outpath
    end
  end

  test 'should copy default stylesheet to target directory if linkcss is specified' do
    sample_outpath = fixture_path 'sample-output.html'
    asciidoctor_stylesheet = fixture_path 'asciidoctor.css'
    coderay_stylesheet = fixture_path 'coderay-asciidoctor.css'
    begin
      invoke_cli %W(-o #{sample_outpath} -a linkcss -a source-highlighter=coderay), 'source-block.adoc'
      assert_path_exists sample_outpath
      assert_path_exists asciidoctor_stylesheet
      assert_path_exists coderay_stylesheet
    ensure
      FileUtils.rm_f sample_outpath
      FileUtils.rm_f asciidoctor_stylesheet
      FileUtils.rm_f coderay_stylesheet
    end
  end

  test 'should not copy coderay stylesheet to target directory when no source blocks where highlighted' do
    sample_outpath = fixture_path 'sample-output.html'
    asciidoctor_stylesheet = fixture_path 'asciidoctor.css'
    coderay_stylesheet = fixture_path 'coderay-asciidoctor.css'
    begin
      invoke_cli %W(-o #{sample_outpath} -a linkcss -a source-highlighter=coderay)
      assert_path_exists sample_outpath
      assert_path_exists asciidoctor_stylesheet
      refute_path_exists coderay_stylesheet
    ensure
      FileUtils.rm_f sample_outpath
      FileUtils.rm_f asciidoctor_stylesheet
      FileUtils.rm_f coderay_stylesheet
    end
  end

  test 'should not copy default stylesheet to target directory if linkcss is set and copycss is unset' do
    sample_outpath = fixture_path 'sample-output.html'
    default_stylesheet = fixture_path 'asciidoctor.css'
    begin
      invoker = invoke_cli %W(-o #{sample_outpath} -a linkcss -a copycss!)
      invoker.document
      assert_path_exists sample_outpath
      refute_path_exists default_stylesheet
    ensure
      FileUtils.rm_f sample_outpath
      FileUtils.rm_f default_stylesheet
    end
  end

  test 'should copy custom stylesheet to target directory if stylesheet and linkcss is specified' do
    destdir = fixture_path 'output'
    sample_outpath = File.join destdir, 'sample-output.html'
    stylesdir = File.join destdir, 'styles'
    custom_stylesheet = File.join stylesdir, 'custom.css'
    begin
      invoker = invoke_cli %W(-o #{sample_outpath} -a linkcss -a copycss=stylesheets/custom.css -a stylesdir=./styles -a stylesheet=custom.css)
      invoker.document
      assert_path_exists sample_outpath
      assert_path_exists custom_stylesheet
    ensure
      FileUtils.rm_f sample_outpath
      FileUtils.rm_f custom_stylesheet
      FileUtils.rmdir stylesdir
      FileUtils.rmdir destdir
    end
  end

  test 'should not copy custom stylesheet to target directory if stylesheet and linkcss are set and copycss is unset' do
    destdir = fixture_path 'output'
    sample_outpath = File.join destdir, 'sample-output.html'
    stylesdir = File.join destdir, 'styles'
    custom_stylesheet = File.join stylesdir, 'custom.css'
    begin
      invoker = invoke_cli %W(-o #{sample_outpath} -a linkcss -a stylesdir=./styles -a stylesheet=custom.css -a copycss!)
      invoker.document
      assert_path_exists sample_outpath
      refute_path_exists custom_stylesheet
    ensure
      FileUtils.rm_f sample_outpath
      FileUtils.rm_f custom_stylesheet
      FileUtils.rmdir stylesdir if File.directory? stylesdir
      FileUtils.rmdir destdir
    end
  end

  test 'should not copy custom stylesheet to target directory if stylesdir is a URI' do
    destdir = fixture_path 'output'
    sample_outpath = File.join destdir, 'sample-output.html'
    stylesdir = File.join destdir, 'http:'
    begin
      invoker = invoke_cli %W(-o #{sample_outpath} -a linkcss -a stylesdir=http://example.org/styles -a stylesheet=custom.css)
      invoker.document
      assert_path_exists sample_outpath
      refute_path_exists stylesdir
    ensure
      FileUtils.rm_f sample_outpath
      FileUtils.rmdir stylesdir if File.directory? stylesdir
      FileUtils.rmdir destdir
    end
  end

  test 'should convert all passed files' do
    basic_outpath = fixture_path 'basic.html'
    sample_outpath = fixture_path 'sample.html'
    begin
      invoke_cli_with_filenames [], %w(basic.adoc sample.adoc)
      assert_path_exists basic_outpath
      assert_path_exists sample_outpath
    ensure
      FileUtils.rm_f basic_outpath
      FileUtils.rm_f sample_outpath
    end
  end

  test 'options should not be modified when processing multiple files' do
    destination_path = File.join testdir, 'test_output'
    basic_outpath = File.join destination_path, 'basic.htm'
    sample_outpath = File.join destination_path, 'sample.htm'
    begin
      invoke_cli_with_filenames %w(-D test/test_output -a outfilesuffix=.htm), %w(basic.adoc sample.adoc)
      assert_path_exists basic_outpath
      assert_path_exists sample_outpath
    ensure
      FileUtils.rm_f basic_outpath
      FileUtils.rm_f sample_outpath
      FileUtils.rmdir destination_path
    end
  end

  test 'should convert all files that matches a glob expression' do
    basic_outpath = fixture_path 'basic.html'
    begin
      invoke_cli_to_buffer [], 'ba*.adoc'
      assert_path_exists basic_outpath
    ensure
      FileUtils.rm_f basic_outpath
    end
  end

  test 'should convert all files that matches an absolute path glob expression' do
    basic_outpath = fixture_path 'basic.html'
    glob = fixture_path 'ba*.adoc'
    # test Windows using backslash-style pathname
    if File::ALT_SEPARATOR == '\\'
      glob = glob.tr '/', '\\'
    end

    begin
      invoke_cli_to_buffer [], glob
      assert_path_exists basic_outpath
    ensure
      FileUtils.rm_f basic_outpath
    end
  end

  test 'should suppress header footer if specified' do
    # NOTE this verifies support for the legacy alias -s
    [%w(-e -o -), %w(-s -o -)].each do |flags|
      invoker = invoke_cli_to_buffer flags
      output = invoker.read_output
      assert_xpath '/html', output, 0
      assert_xpath '/*[@id="preamble"]', output, 1
    end
  end

  test 'should write page for each alternate manname' do
    outdir = fixturedir
    outfile_1 = File.join outdir, 'eve.1'
    outfile_2 = File.join outdir, 'islifeform.1'
    input = <<~'EOS'
    = eve(1)
    Andrew Stanton
    v1.0.0
    :doctype: manpage
    :manmanual: EVE
    :mansource: EVE

    == NAME

    eve, islifeform - analyzes an image to determine if it's a picture of a life form

    == SYNOPSIS

    *eve* ['OPTION']... 'FILE'...
    EOS

    begin
      invoke_cli(%W(-b manpage -o #{outfile_1}), '-') { input }
      assert_path_exists outfile_1
      assert_path_exists outfile_2
      assert_equal '.so eve.1', (File.read outfile_2, mode: Asciidoctor::FILE_READ_MODE).chomp
    ensure
      FileUtils.rm_f outfile_1
      FileUtils.rm_f outfile_2
    end
  end

  test 'should output a trailing newline to stdout' do
    invoker = nil
    output = nil
    redirect_streams do |out|
      invoker = invoke_cli %w(-o -)
      output = out.string
    end
    refute_nil invoker
    refute_nil output
    assert output.end_with?("\n")
  end

  test 'should set backend to html5 if specified' do
    invoker = invoke_cli_to_buffer %w(-b html5 -o -)
    doc = invoker.document
    assert_equal 'html5', doc.attr('backend')
    assert_equal '.html', doc.attr('outfilesuffix')
    output = invoker.read_output
    assert_xpath '/html', output, 1
  end

  test 'should set backend to docbook5 if specified' do
    invoker = invoke_cli_to_buffer %w(-b docbook5 -a xmlns -o -)
    doc = invoker.document
    assert_equal 'docbook5', doc.attr('backend')
    assert_equal '.xml', doc.attr('outfilesuffix')
    output = invoker.read_output
    assert_xpath '/xmlns:article', output, 1
  end

  test 'should set doctype to article if specified' do
    invoker = invoke_cli_to_buffer %w(-d article -o -)
    doc = invoker.document
    assert_equal 'article', doc.attr('doctype')
    output = invoker.read_output
    assert_xpath '/html/body[@class="article"]', output, 1
  end

  test 'should set doctype to book if specified' do
    invoker = invoke_cli_to_buffer %w(-d book -o -)
    doc = invoker.document
    assert_equal 'book', doc.attr('doctype')
    output = invoker.read_output
    assert_xpath '/html/body[@class="book"]', output, 1
  end

  test 'should warn if doctype is inline and the first block is not a candidate for inline conversion' do
    ['== Section Title', 'image::tiger.png[]'].each do |input|
      warnings = redirect_streams do |_, err|
        invoke_cli_to_buffer(%w(-d inline), '-') { input }
        err.string
      end
      assert_match(/WARNING: no inline candidate/, warnings)
    end
  end

  test 'should not warn if doctype is inline and the document has no blocks' do
    warnings = redirect_streams do |_, err|
      invoke_cli_to_buffer(%w(-d inline), '-') { '// comment' }
      err.string
    end
    refute_match(/WARNING/, warnings)
  end

  test 'should not warn if doctype is inline and the document contains multiple blocks' do
    warnings = redirect_streams do |_, err|
      invoke_cli_to_buffer(%w(-d inline), '-') { %(paragraph one\n\nparagraph two\n\nparagraph three) }
      err.string
    end
    refute_match(/WARNING/, warnings)
  end

  test 'should add source location to blocks when sourcemap option is specified' do
    sample_filepath = fixture_path 'sample.adoc'
    invoker = invoke_cli_to_buffer %w(--sourcemap -o -)
    doc = invoker.document
    all_blocks = doc.find_by
    refute_equal 0, all_blocks.size
    doc.find_by.each do |block|
      refute_nil block.source_location
    end
    assert_equal sample_filepath, doc.blocks[0].source_location.file
    assert_equal 6, doc.blocks[0].source_location.lineno
  end

  test 'should locate custom templates based on template dir, template engine and backend' do
    custom_backend_root = fixture_path 'custom-backends'
    invoker = invoke_cli_to_buffer %W(-E haml -T #{custom_backend_root} -o -)
    doc = invoker.document
    assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
    selected = doc.converter.find_converter 'paragraph'
    assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
    assert_kind_of haml_template_class, selected.templates['paragraph']
  end

  test 'should load custom templates from multiple template directories' do
    custom_backend_1 = fixture_path 'custom-backends/haml/html5'
    custom_backend_2 = fixture_path 'custom-backends/haml/html5-tweaks'
    invoker = invoke_cli_to_buffer %W(-T #{custom_backend_1} -T #{custom_backend_2} -o - -e)
    output = invoker.read_output
    assert_css '.paragraph', output, 0
    assert_css '#preamble > .sectionbody > p', output, 1
  end

  test 'should set attribute with value' do
    invoker = invoke_cli_to_buffer %w(--trace -a idprefix=id -e -o -)
    doc = invoker.document
    assert_equal 'id', doc.attr('idprefix')
    output = invoker.read_output
    assert_xpath '//h2[@id="idsection_a"]', output, 1
  end

  test 'should set attribute with value containing equal sign' do
    invoker = invoke_cli_to_buffer %w(--trace -a toc -a toc-title=t=o=c -o -)
    doc = invoker.document
    assert_equal 't=o=c', doc.attr('toc-title')
    output = invoker.read_output
    assert_xpath '//*[@id="toctitle"][text() = "t=o=c"]', output, 1
  end

  test 'should set attribute with quoted value containing a space' do
    # emulating commandline arguments: --trace -a toc -a note-caption="Note to self:" -o -
    invoker = invoke_cli_to_buffer ['--trace', '-a', 'toc', '-a', 'note-caption=Note to self:', '-o', '-']
    doc = invoker.document
    assert_equal 'Note to self:', doc.attr('note-caption')
    output = invoker.read_output
    assert_xpath %(//*[#{contains_class 'admonitionblock'}]//*[@class='title'][text() = 'Note to self:']), output, 1
  end

  test 'should not set attribute ending in @ if defined in document' do
    invoker = invoke_cli_to_buffer %w(--trace -a idprefix=id@ -e -o -)
    doc = invoker.document
    assert_equal 'id_', doc.attr('idprefix')
    output = invoker.read_output
    assert_xpath '//h2[@id="id_section_a"]', output, 1
  end

  test 'should set attribute with no value' do
    invoker = invoke_cli_to_buffer %w(-a icons -e -o -)
    doc = invoker.document
    assert_equal '', doc.attr('icons')
    output = invoker.read_output
    assert_xpath '//*[@class="admonitionblock note"]//img[@alt="Note"]', output, 1
  end

  test 'should unset attribute ending in bang' do
    invoker = invoke_cli_to_buffer %w(-a sectids! -e -o -)
    doc = invoker.document
    refute doc.attr?('sectids')
    output = invoker.read_output
    # leave the count loose in case we add more sections
    assert_xpath '//h2[not(@id)]', output
  end

  test 'default mode for cli should be unsafe' do
    invoker = invoke_cli_to_buffer %w(-o /dev/null)
    doc = invoker.document
    assert_equal Asciidoctor::SafeMode::UNSAFE, doc.safe
  end

  test 'should set safe mode if specified' do
    invoker = invoke_cli_to_buffer %w(--safe -o /dev/null)
    doc = invoker.document
    assert_equal Asciidoctor::SafeMode::SAFE, doc.safe
  end

  test 'should set safe mode to specified level' do
    Asciidoctor::SafeMode.names.each do |name|
      invoker = invoke_cli_to_buffer %W(-S #{name} -o /dev/null)
      doc = invoker.document
      assert_equal (Asciidoctor::SafeMode.value_for_name name), doc.safe
    end
  end

  test 'should set eRuby impl if specified' do
    invoker = invoke_cli_to_buffer %w(--eruby erubi -o /dev/null)
    doc = invoker.document
    assert_equal 'erubi', doc.instance_variable_get('@options')[:eruby]
  end

  test 'should force default external encoding to UTF-8' do
    input_path = fixture_path 'encoding.adoc'
    # using open3 to work around a bug in JRuby process_manager.rb,
    # which tries to run a gsub on stdout prematurely breaking the test
    # warnings may be issued, so don't assert on stderr
    stdout_lines = run_command(asciidoctor_cmd, '-o', '-', '--trace', input_path, env: { 'LANG' => 'US-ASCII' }) {|out| out.readlines }
    refute_empty stdout_lines
    # NOTE Ruby on Windows runs with a IBM437 encoding by default
    stdout_lines.each {|l| l.force_encoding Encoding::UTF_8 } unless Encoding.default_external == Encoding::UTF_8
    stdout_str = stdout_lines.join
    assert_includes stdout_str, 'Codierungen sind verrückt auf älteren Versionen von Ruby'
  end

  test 'should force stdio encoding to UTF-8' do
    cmd = asciidoctor_cmd ['-E', 'IBM866:IBM866']
    # NOTE configure-stdin.rb populates stdin
    result = run_command(cmd, '-r', (fixture_path 'configure-stdin.rb'), '-e', '-o', '-', '-') {|out| out.read }
    # NOTE Ruby on Windows runs with a IBM437 encoding by default
    result.force_encoding Encoding::UTF_8 unless Encoding.default_external == Encoding::UTF_8
    assert_equal Encoding::UTF_8, result.encoding
    assert_include '<p>é</p>', result
    assert_include '<p>IBM866:IBM866</p>', result
  end

  test 'should not fail to load if call to Dir.home fails' do
    cmd = asciidoctor_cmd ['-r', (fixture_path 'undef-dir-home.rb')]
    result = run_command(cmd, '-e', '-o', '-', (fixture_path 'basic.adoc')) {|out| out.read }
    assert_include 'Body content', result
  end

  test 'should print timings when -t flag is specified' do
    input = 'Sample *AsciiDoc*'
    invoker = nil
    error = nil
    redirect_streams do |_, err|
      invoker = invoke_cli(%w(-t -o /dev/null), '-') { input }
      error = err.string
    end
    refute_nil invoker
    refute_nil error
    assert_match(/Total time/, error)
  end

  test 'should show timezone as UTC if system TZ is set to UTC' do
    input_path = fixture_path 'doctime-localtime.adoc'
    output = run_command(asciidoctor_cmd, '-d', 'inline', '-o', '-', '-e', input_path, env: { 'TZ' => 'UTC', 'SOURCE_DATE_EPOCH' => nil, 'IGNORE_SOURCE_DATE_EPOCH' => '1' }) {|out| out.read }
    doctime, localtime = output.lines.map(&:chomp)
    assert doctime.end_with?(' UTC')
    assert localtime.end_with?(' UTC')
  end

  test 'should show timezone as offset if system TZ is not set to UTC' do
    input_path = fixture_path 'doctime-localtime.adoc'
    output = run_command(asciidoctor_cmd, '-d', 'inline', '-o', '-', '-e', input_path, env: { 'TZ' => 'EST+5', 'SOURCE_DATE_EPOCH' => nil, 'IGNORE_SOURCE_DATE_EPOCH' => '1' }) {|out| out.read }
    doctime, localtime = output.lines.map(&:chomp)
    assert doctime.end_with?(' -0500')
    assert localtime.end_with?(' -0500')
  end

  test 'should use SOURCE_DATE_EPOCH as modified time of input file and local time' do
    old_source_date_epoch = ENV.delete 'SOURCE_DATE_EPOCH'
    begin
      ENV['SOURCE_DATE_EPOCH'] = '1234123412'
      sample_filepath = fixture_path 'sample.adoc'
      invoker = invoke_cli_to_buffer %w(-o /dev/null), sample_filepath
      doc = invoker.document
      assert_equal '2009-02-08', (doc.attr 'docdate')
      assert_equal '2009', (doc.attr 'docyear')
      assert_match(/2009-02-08 20:03:32 UTC/, (doc.attr 'docdatetime'))
      assert_equal '2009-02-08', (doc.attr 'localdate')
      assert_equal '2009', (doc.attr 'localyear')
      assert_match(/2009-02-08 20:03:32 UTC/, (doc.attr 'localdatetime'))
    ensure
      if old_source_date_epoch
        ENV['SOURCE_DATE_EPOCH'] = old_source_date_epoch
      else
        ENV.delete 'SOURCE_DATE_EPOCH'
      end
    end
  end

  test 'should fail if SOURCE_DATE_EPOCH is malformed' do
    old_source_date_epoch = ENV.delete 'SOURCE_DATE_EPOCH'
    begin
      ENV['SOURCE_DATE_EPOCH'] = 'aaaaaaaa'
      sample_filepath = fixture_path 'sample.adoc'
      assert_equal 1, (invoke_cli_to_buffer %w(-o /dev/null), sample_filepath).code
    ensure
      if old_source_date_epoch
        ENV['SOURCE_DATE_EPOCH'] = old_source_date_epoch
      else
        ENV.delete 'SOURCE_DATE_EPOCH'
      end
    end
  end
end
