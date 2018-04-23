# encoding: UTF-8
unless defined? ASCIIDOCTOR_PROJECT_DIR
  $: << File.dirname(__FILE__); $:.uniq!
  require 'test_helper'
end
require 'asciidoctor/cli/options'
require 'asciidoctor/cli/invoker'

context 'Invoker' do
  test 'should parse source and render as html5 article by default' do
    invoker = nil
    output = nil
    redirect_streams do |out, err|
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
    sample_filepath = fixture_path 'sample.asciidoc'
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
    sample_filepath = fixture_path 'sample.asciidoc'
    invoker = invoke_cli_to_buffer %w(-o /dev/null -a docdate=2015-01-01 -a doctime=10:00:00-07:00), sample_filepath
    doc = invoker.document
    assert doc.attr?('docdate', '2015-01-01')
    assert doc.attr?('docyear', '2015')
    assert doc.attr?('doctime', '10:00:00-07:00')
    assert doc.attr?('docdatetime', '2015-01-01 10:00:00-07:00')
  end

  test 'should accept document from stdin and write to stdout' do
    invoker = invoke_cli_to_buffer(%w(-s), '-') { 'content' }
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
    io = STDIN.dup
    class << io
      def readlines
        ['paragraph']
      end
    end
    invoker = invoke_cli_to_buffer(%w(-s), '-') { io }
    assert_equal 0, invoker.code
    assert_equal 1, invoker.document.blocks.size
  end

  test 'should accept document from stdin and write to output file' do
    sample_outpath = fixture_path 'sample-output.html'
    begin
      invoker = invoke_cli(%W(-s -o #{sample_outpath}), '-') { 'content' }
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
      assert File.exist?(sample_outpath)
    ensure
      FileUtils.rm_f(sample_outpath)
    end
  end

  test 'should fail if input file matches resolved output file' do
    invoker = invoke_cli_to_buffer %W(-a outfilesuffix=.asciidoc), 'sample.asciidoc'
    assert_match(/input file and output file cannot be the same/, invoker.read_error)
  end

  test 'should fail if input file matches specified output file' do
    sample_outpath = fixture_path 'sample.asciidoc'
    invoker = invoke_cli_to_buffer %W(-o #{sample_outpath}), 'sample.asciidoc'
    assert_match(/input file and output file cannot be the same/, invoker.read_error)
  end

  test 'should accept input from named pipe and output to stdout' do
    sample_inpath = fixture_path 'sample-pipe.adoc'
    begin
      %x(mkfifo #{sample_inpath})
      write_thread = Thread.new do
        IO.write sample_inpath, 'pipe content'
      end
      invoker = invoke_cli_to_buffer %w(-a stylesheet!), sample_inpath
      result = invoker.read_output
      assert_match(/pipe content/, result)
      write_thread.join
    ensure
      FileUtils.rm_f sample_inpath
    end
  end if RUBY_MIN_VERSION_1_9 && !windows?

  test 'should allow docdir to be specified when input is a string' do
    expected_docdir = fixturedir
    invoker = invoke_cli_to_buffer(%w(-s --base-dir test/fixtures -o /dev/null), '-') { 'content' }
    doc = invoker.document
    assert_equal expected_docdir, doc.attr('docdir')
    assert_equal expected_docdir, doc.base_dir
  end

  test 'should display version and exit' do
    expected = %(Asciidoctor #{Asciidoctor::VERSION} [https://asciidoctor.org]\nRuntime Environment (#{RUBY_DESCRIPTION}))
    ['--version', '-V'].each do |switch|
      actual = nil
      redirect_streams do |out, err|
        invoke_cli [switch]
        actual = out.string.rstrip
      end
      refute_nil actual
      assert actual.start_with?(expected), %(Expected to print version when using #{switch} switch)
    end
  end

  test 'should print warnings to stderr by default' do
    input = <<-EOS
2. second
3. third
    EOS
    warnings = nil
    redirect_streams do |out, err|
      invoke_cli_to_buffer(%w(-o /dev/null), '-') { input }
      warnings = err.string
    end
    assert_match(/WARNING/, warnings)
  end

  test 'should silence warnings if -q flag is specified' do
    input = <<-EOS
2. second
3. third
    EOS
    warnings = nil
    redirect_streams do |out, err|
      invoke_cli_to_buffer(%w(-q -o /dev/null), '-') { input }
      warnings = err.string
    end
    assert_equal '', warnings
  end

  test 'should return non-zero exit code if failure level is reached' do
    input = <<-EOS
2. second
3. third
    EOS
    exit_code, messages = redirect_streams do |_, err|
      [invoke_cli(%w(-q --failure-level=WARN -o /dev/null), '-') { input }.code, err.string]
    end
    assert_equal 1, exit_code
    assert messages.empty?
  end

  test 'should report usage if no input file given' do
    redirect_streams do |out, err|
      invoke_cli [], nil
      assert_match(/Usage:/, err.string)
    end
  end

  test 'should report error if input file does not exist' do
    redirect_streams do |out, err|
      invoker = invoke_cli [], 'missing_file.asciidoc'
      assert_match(/input file .* is missing/, err.string)
      assert_equal 1, invoker.code
    end
  end

  test 'should treat extra arguments as files' do
    redirect_streams do |out, err|
      invoker = invoke_cli %w(-o /dev/null extra arguments sample.asciidoc), nil
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
      assert File.exist?(sample_outpath)
      output = IO.read(sample_outpath)
      refute_empty output
      assert_xpath '/html', output, 1
      assert_xpath '/html/head', output, 1
      assert_xpath '/html/body', output, 1
      assert_xpath '/html/head/title[text() = "Document Title"]', output, 1
      assert_xpath '/html/body/*[@id="header"]/h1[text() = "Document Title"]', output, 1
    ensure
      FileUtils.rm_f(sample_outpath)
    end
  end

  test 'should output to file in destination directory if set' do
    destination_path = File.join testdir, 'test_output'
    sample_outpath = File.join destination_path, 'sample.html'
    begin
      FileUtils.mkdir_p(destination_path)
      # QUESTION should -D be relative to working directory or source directory?
      invoker = invoke_cli %w(-D test/test_output)
      #invoker = invoke_cli %w(-D ../../test/test_output)
      doc = invoker.document
      assert_equal sample_outpath, doc.attr('outfile')
      assert File.exist?(sample_outpath)
    ensure
      FileUtils.rm_f(sample_outpath)
      FileUtils.rmdir(destination_path)
    end
  end

  test 'should preserve directory structure in destination directory if source directory is set' do
    sample_inpath = 'subdir/index.adoc'
    destination_path = 'test_output'
    destination_subdir_path = File.join destination_path, 'subdir'
    sample_outpath = File.join destination_subdir_path, 'index.html'
    begin
      FileUtils.mkdir_p(destination_path)
      invoke_cli %W(-D #{destination_path} -R test/fixtures), sample_inpath
      assert File.directory?(destination_subdir_path)
      assert File.exist?(sample_outpath)
    ensure
      FileUtils.rm_f(sample_outpath)
      FileUtils.rmdir(destination_subdir_path)
      FileUtils.rmdir(destination_path)
    end
  end

  test 'should output to file specified' do
    sample_outpath = fixture_path 'sample-output.html'
    begin
      invoker = invoke_cli %W(-o #{sample_outpath})
      doc = invoker.document
      assert_equal sample_outpath, doc.attr('outfile')
      assert File.exist?(sample_outpath)
    ensure
      FileUtils.rm_f(sample_outpath)
    end
  end

  test 'should copy default stylesheet to target directory if linkcss is specified' do
    sample_outpath = fixture_path 'sample-output.html'
    asciidoctor_stylesheet = fixture_path 'asciidoctor.css'
    coderay_stylesheet = fixture_path 'coderay-asciidoctor.css'
    begin
      invoker = invoke_cli %W(-o #{sample_outpath} -a linkcss -a source-highlighter=coderay)
      invoker.document
      assert File.exist?(sample_outpath)
      assert File.exist?(asciidoctor_stylesheet)
      assert File.exist?(coderay_stylesheet)
    ensure
      FileUtils.rm_f(sample_outpath)
      FileUtils.rm_f(asciidoctor_stylesheet)
      FileUtils.rm_f(coderay_stylesheet)
    end
  end

  test 'should not copy default stylesheet to target directory if linkcss is set and copycss is unset' do
    sample_outpath = fixture_path 'sample-output.html'
    default_stylesheet = fixture_path 'asciidoctor.css'
    begin
      invoker = invoke_cli %W(-o #{sample_outpath} -a linkcss -a copycss!)
      invoker.document
      assert File.exist?(sample_outpath)
      refute File.exist?(default_stylesheet)
    ensure
      FileUtils.rm_f(sample_outpath)
      FileUtils.rm_f(default_stylesheet)
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
      assert File.exist?(sample_outpath)
      assert File.exist?(custom_stylesheet)
    ensure
      FileUtils.rm_f(sample_outpath)
      FileUtils.rm_f(custom_stylesheet)
      FileUtils.rmdir(stylesdir)
      FileUtils.rmdir(destdir)
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
      assert File.exist?(sample_outpath)
      refute File.exist?(custom_stylesheet)
    ensure
      FileUtils.rm_f(sample_outpath)
      FileUtils.rm_f(custom_stylesheet)
      FileUtils.rmdir(stylesdir) if File.directory? stylesdir
      FileUtils.rmdir(destdir)
    end
  end

  test 'should not copy custom stylesheet to target directory if stylesdir is a URI' do
    destdir = fixture_path 'output'
    sample_outpath = File.join destdir, 'sample-output.html'
    stylesdir = File.join destdir, 'http:'
    begin
      invoker = invoke_cli %W(-o #{sample_outpath} -a linkcss -a stylesdir=http://example.org/styles -a stylesheet=custom.css)
      invoker.document
      assert File.exist?(sample_outpath)
      refute File.exist?(stylesdir)
    ensure
      FileUtils.rm_f(sample_outpath)
      FileUtils.rmdir(stylesdir) if File.directory? stylesdir
      FileUtils.rmdir(destdir)
    end
  end

  test 'should render all passed files' do
    basic_outpath = fixture_path 'basic.html'
    sample_outpath = fixture_path 'sample.html'
    begin
      invoke_cli_with_filenames [], %w(basic.asciidoc sample.asciidoc)
      assert File.exist?(basic_outpath)
      assert File.exist?(sample_outpath)
    ensure
      FileUtils.rm_f(basic_outpath)
      FileUtils.rm_f(sample_outpath)
    end
  end

  test 'options should not be modified when processing multiple files' do
    destination_path = File.join testdir, 'test_output'
    basic_outpath = File.join destination_path, 'basic.htm'
    sample_outpath = File.join destination_path, 'sample.htm'
    begin
      invoke_cli_with_filenames %w(-D test/test_output -a outfilesuffix=.htm), %w(basic.asciidoc sample.asciidoc)
      assert File.exist?(basic_outpath)
      assert File.exist?(sample_outpath)
    ensure
      FileUtils.rm_f(basic_outpath)
      FileUtils.rm_f(sample_outpath)
      FileUtils.rmdir(destination_path)
    end
  end

  test 'should render all files that matches a glob expression' do
    basic_outpath = fixture_path 'basic.html'
    begin
      invoke_cli_to_buffer [], "ba*.asciidoc"
      assert File.exist?(basic_outpath)
    ensure
      FileUtils.rm_f(basic_outpath)
    end
  end

  test 'should render all files that matches an absolute path glob expression' do
    basic_outpath = fixture_path 'basic.html'
    glob = fixture_path 'ba*.asciidoc'
    # test Windows using backslash-style pathname
    if File::ALT_SEPARATOR == '\\'
      glob = glob.tr '/', '\\'
    end

    begin
      invoke_cli_to_buffer [], glob
      assert File.exist?(basic_outpath)
    ensure
      FileUtils.rm_f(basic_outpath)
    end
  end

  test 'should suppress header footer if specified' do
    invoker = invoke_cli_to_buffer %w(-s -o -)
    output = invoker.read_output
    assert_xpath '/html', output, 0
    assert_xpath '/*[@id="preamble"]', output, 1
  end

  test 'should write page for each alternate manname' do
    outdir = fixturedir
    outfile_1 = File.join outdir, 'eve.1'
    outfile_2 = File.join outdir, 'islifeform.1'
    input = <<-EOS
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
      assert File.exist?(outfile_1)
      assert File.exist?(outfile_2)
      assert_equal '.so eve.1', (IO.read outfile_2).chomp
    ensure
      FileUtils.rm_f outfile_1
      FileUtils.rm_f outfile_2
    end
  end

  test 'should output a trailing endline to stdout' do
    invoker = nil
    output = nil
    redirect_streams do |out, err|
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

  test 'should set backend to docbook45 if specified' do
    invoker = invoke_cli_to_buffer %w(-b docbook45 -a xmlns -o -)
    doc = invoker.document
    assert_equal 'docbook45', doc.attr('backend')
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
      warnings = redirect_streams do |out, err|
        invoke_cli_to_buffer(%w(-d inline), '-') { input }
        err.string
      end
      assert_match(/WARNING: no inline candidate/, warnings)
    end
  end

  test 'should not warn if doctype is inline and the document has no blocks' do
    warnings = redirect_streams do |out, err|
      invoke_cli_to_buffer(%w(-d inline), '-') { '// comment' }
      err.string
    end
    refute_match(/WARNING/, warnings)
  end

  test 'should not warn if doctype is inline and the document contains multiple blocks' do
    warnings = redirect_streams do |out, err|
      invoke_cli_to_buffer(%w(-d inline), '-') { %(paragraph one\n\nparagraph two\n\nparagraph three) }
      err.string
    end
    refute_match(/WARNING/, warnings)
  end

  test 'should locate custom templates based on template dir, template engine and backend' do
    custom_backend_root = fixture_path 'custom-backends'
    invoker = invoke_cli_to_buffer %W(-E haml -T #{custom_backend_root} -o -)
    doc = invoker.document
    assert_kind_of Asciidoctor::Converter::CompositeConverter, doc.converter
    selected = doc.converter.find_converter 'paragraph'
    assert_kind_of Asciidoctor::Converter::TemplateConverter, selected
    assert_kind_of Tilt::HamlTemplate, selected.templates['paragraph']
  end

  test 'should load custom templates from multiple template directories' do
    custom_backend_1 = fixture_path 'custom-backends/haml/html5'
    custom_backend_2 = fixture_path 'custom-backends/haml/html5-tweaks'
    invoker = invoke_cli_to_buffer %W(-T #{custom_backend_1} -T #{custom_backend_2} -o - -s)
    output = invoker.read_output
    assert_css '.paragraph', output, 0
    assert_css '#preamble > .sectionbody > p', output, 1
  end

  test 'should set attribute with value' do
    invoker = invoke_cli_to_buffer %w(--trace -a idprefix=id -s -o -)
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
    invoker = invoke_cli_to_buffer %w(--trace -a toc -a note-caption=Note\ to\ self: -o -)
    doc = invoker.document
    assert_equal 'Note to self:', doc.attr('note-caption')
    output = invoker.read_output
    assert_xpath %(//*[#{contains_class('admonitionblock')}]//*[@class='title'][text() = 'Note to self:']), output, 1
  end

  test 'should not set attribute ending in @ if defined in document' do
    invoker = invoke_cli_to_buffer %w(--trace -a idprefix=id@ -s -o -)
    doc = invoker.document
    assert_equal 'id_', doc.attr('idprefix')
    output = invoker.read_output
    assert_xpath '//h2[@id="id_section_a"]', output, 1
  end

  test 'should set attribute with no value' do
    invoker = invoke_cli_to_buffer %w(-a icons -s -o -)
    doc = invoker.document
    assert_equal '', doc.attr('icons')
    output = invoker.read_output
    assert_xpath '//*[@class="admonitionblock note"]//img[@alt="Note"]', output, 1
  end

  test 'should unset attribute ending in bang' do
    invoker = invoke_cli_to_buffer %w(-a sectids! -s -o -)
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
    levels = {
      'unsafe' => Asciidoctor::SafeMode::UNSAFE,
      'safe'   => Asciidoctor::SafeMode::SAFE,
      'server' => Asciidoctor::SafeMode::SERVER,
      'secure' => Asciidoctor::SafeMode::SECURE,
    }
    levels.each do |name, const|
      invoker = invoke_cli_to_buffer %W(-S #{name} -o /dev/null)
      doc = invoker.document
      assert_equal const, doc.safe
    end
  end

  test 'should set eRuby impl if specified' do
    invoker = invoke_cli_to_buffer %w(--eruby erubis -o /dev/null)
    doc = invoker.document
    assert_equal 'erubis', doc.instance_variable_get('@options')[:eruby]
  end

  test 'should force default external encoding to UTF-8' do
    executable = File.join ASCIIDOCTOR_PROJECT_DIR, 'bin', 'asciidoctor'
    input_path = fixture_path 'encoding.asciidoc'
    old_lang = ENV['LANG']
    ENV['LANG'] = 'US-ASCII'
    begin
      # using open3 to work around a bug in JRuby process_manager.rb,
      # which tries to run a gsub on stdout prematurely breaking the test
      require 'open3'
      #cmd = "#{executable} -o - --trace #{input_path}"
      cmd = "#{File.join RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name']} #{executable} -o - --trace #{input_path}"
      _, out, _ = Open3.popen3 cmd
      #stderr_lines = stderr.readlines
      # warnings may be issued, so don't assert on stderr
      #assert_empty stderr_lines, 'Command failed. Expected to receive a rendered document.'
      stdout_lines = out.readlines
      refute_empty stdout_lines
      stdout_lines.each {|l| l.force_encoding Encoding::UTF_8 } if Asciidoctor::FORCE_ENCODING
      stdout_str = stdout_lines.join
      assert_includes stdout_str, 'Codierungen sind verrückt auf älteren Versionen von Ruby'
    ensure
      ENV['LANG'] = old_lang
    end
  end

  test 'should print timings when -t flag is specified' do
    input = <<-EOS
    Sample *AsciiDoc*
    EOS
    invoker = nil
    error = nil
    redirect_streams do |out, err|
      invoker = invoke_cli(%w(-t -o /dev/null), '-') { input }
      error = err.string
    end
    refute_nil invoker
    refute_nil error
    assert_match(/Total time/, error)
  end

  test 'should use SOURCE_DATE_EPOCH as modified time of input file and local time' do
    old_source_date_epoch = ENV.delete 'SOURCE_DATE_EPOCH'
    begin
      ENV['SOURCE_DATE_EPOCH'] = '1234123412'
      sample_filepath = fixture_path 'sample.asciidoc'
      invoker = invoke_cli_to_buffer %w(-o /dev/null), sample_filepath
      doc = invoker.document
      assert_equal '2009-02-08', (doc.attr 'docdate')
      assert_equal '2009', (doc.attr 'docyear')
      assert_match(/2009-02-08 20:03:32 (GMT|UTC)/, (doc.attr 'docdatetime'))
      assert_equal '2009-02-08', (doc.attr 'localdate')
      assert_equal '2009', (doc.attr 'localyear')
      assert_match(/2009-02-08 20:03:32 (GMT|UTC)/, (doc.attr 'localdatetime'))
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
      sample_filepath = fixture_path 'sample.asciidoc'
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
