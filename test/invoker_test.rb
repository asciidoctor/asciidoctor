require 'test_helper'
require 'asciidoctor/cli/options'
require 'asciidoctor/cli/invoker'

context 'Invoker' do
  test 'should parse source and render as html5 article by default' do
    invoker = nil
    output = nil
    redirect_streams do |stdout, stderr|
      invoker = invoke_cli %w(-o -)
      output = stdout.string
    end
    assert !invoker.nil?
    doc = invoker.document
    assert !doc.nil?
    assert_equal 'Document Title', doc.doctitle
    assert_equal 'Doc Writer', doc.attr('author')
    assert_equal 'html5', doc.attr('backend')
    assert_equal '.html', doc.attr('outfilesuffix')
    assert_equal 'article', doc.attr('doctype')
    assert doc.blocks?
    assert_equal :preamble, doc.blocks.first.context
    assert !output.empty?
    assert_xpath '/html', output, 1
    assert_xpath '/html/head', output, 1
    assert_xpath '/html/body', output, 1
    assert_xpath '/html/head/title[text() = "Document Title"]', output, 1
    assert_xpath '/html/body[@class="article"]/*[@id="header"]/h1[text() = "Document Title"]', output, 1
  end

  test 'should set implicit doc info attributes' do
    sample_filepath = File.expand_path(File.join(File.dirname(__FILE__), 'fixtures', 'sample.asciidoc'))
    sample_filedir = File.expand_path(File.join(File.dirname(__FILE__), 'fixtures'))
    invoker = invoke_cli_to_buffer %w(-o /dev/null), sample_filepath
    doc = invoker.document
    assert_equal 'sample', doc.attr('docname')
    assert_equal sample_filepath, doc.attr('docfile')
    assert_equal sample_filedir, doc.attr('docdir')
    assert doc.attr?('docdate')
    assert doc.attr?('doctime')
    assert doc.attr?('docdatetime')
    assert invoker.read_output.empty?
  end

  test 'should accept document from stdin and write to stdout' do
    invoker = invoke_cli_to_buffer(%w(-s), '-') { 'content' }
    doc = invoker.document
    assert !doc.attr?('docname')
    assert !doc.attr?('docfile')
    assert_equal Dir.pwd, doc.attr('docdir')
    assert_equal doc.attr('docdate'), doc.attr('localdate')
    assert_equal doc.attr('doctime'), doc.attr('localtime')
    assert_equal doc.attr('docdatetime'), doc.attr('localdatetime')
    assert !doc.attr?('outfile')
    output = invoker.read_output
    assert !output.empty?
    assert_xpath '/*[@class="paragraph"]/p[text()="content"]', output, 1
  end

  test 'should allow docdir to be specified when input is a string' do
    expected_docdir = File.expand_path(File.join(File.dirname(__FILE__), 'fixtures'))
    invoker = invoke_cli_to_buffer(%w(-s --base-dir test/fixtures -o /dev/null), '-') { 'content' }
    doc = invoker.document
    assert_equal expected_docdir, doc.attr('docdir')
    assert_equal expected_docdir, doc.base_dir
  end

  test 'should display version and exit' do
    redirect_streams do |stdout, stderr|
      invoke_cli %w(--version)
      assert_equal "Asciidoctor #{Asciidoctor::VERSION} [http://asciidoctor.org]", stdout.string.chomp
    end
  end

  test 'should report usage if no input file given' do
    redirect_streams do |stdout, stderr|
      invoke_cli [], nil
      assert_match(/Usage:/, stdout.string)
    end
  end

  test 'should report error if input file does not exist' do
    redirect_streams do |stdout, stderr|
      invoker = invoke_cli [], 'missing_file.asciidoc'
      assert_match(/input file .* missing/, stderr.string)
      assert_equal 1, invoker.code
    end
  end

  test 'should fail with too many arguments if spaces in file name not escaped' do
    redirect_streams do |stdout, stderr|
      invoker = invoke_cli %w(-o /dev/null filename with spaces.asciidoc), nil
      assert_match(/too many arguments/, stderr.string)
      assert_equal 1, invoker.code
    end
  end

  test 'should handle file name with spaces if properly escaped' do
    redirect_streams do |stdout, stderr|
      invoker = invoke_cli %w(-o /dev/null test/fixtures/filename\ with\ spaces.asciidoc), nil
      assert !invoker.document.nil?
    end
  end

  test 'should output to file name based on input file name' do
    sample_outpath = File.expand_path(File.join(File.dirname(__FILE__), 'fixtures', 'sample.html'))
    invoker = invoke_cli
    doc = invoker.document
    assert_equal sample_outpath, doc.attr('outfile')
    assert File.exist?(sample_outpath)
    output = File.read(sample_outpath)
    FileUtils::rm(sample_outpath)
    assert !output.empty?
    assert_xpath '/html', output, 1
    assert_xpath '/html/head', output, 1
    assert_xpath '/html/body', output, 1
    assert_xpath '/html/head/title[text() = "Document Title"]', output, 1
    assert_xpath '/html/body/*[@id="header"]/h1[text() = "Document Title"]', output, 1
  end

  test 'should output to file in destination directory if set' do
    destination_path = File.expand_path(File.join(File.dirname(__FILE__), 'tmp'))
    sample_outpath = File.join(destination_path, 'sample.html')
    FileUtils::mkdir(destination_path) 
    invoker = invoke_cli %w(-D test/tmp)
    doc = invoker.document
    assert_equal sample_outpath, doc.attr('outfile')
    assert File.exist?(sample_outpath)
    FileUtils::rm(sample_outpath)
    FileUtils::rmdir(destination_path)
  end

  test 'should output to file specified' do
    sample_outpath = File.expand_path(File.join(File.dirname(__FILE__), 'fixtures', 'sample-output.html'))
    invoker = invoke_cli %W(-o #{sample_outpath})
    doc = invoker.document
    assert_equal sample_outpath, doc.attr('outfile')
    assert File.exist?(sample_outpath)
    FileUtils::rm(sample_outpath)
  end

  test 'should suppress header footer if specified' do
    invoker = invoke_cli_to_buffer %w(-s -o -)
    output = invoker.read_output
    assert_xpath '/html', output, 0
    assert_xpath '/*[@id="preamble"]', output, 1
  end

  test 'should not compact output by default' do
    invoker = invoke_cli_to_buffer(%w(-s -o -), '-') { 'content' }
    output = invoker.read_output
    assert_match(/\n[[:blank:]]*\n/, output)
  end

  test 'should compact output if specified' do
    invoker = invoke_cli_to_buffer(%w(-C -s -o -), '-') { 'content' }
    output = invoker.read_output
    assert_no_match(/\n[[:blank:]]*\n/, output)
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
    invoker = invoke_cli_to_buffer %w(-b docbook45 -o -)
    doc = invoker.document
    assert_equal 'docbook45', doc.attr('backend')
    assert_equal '.xml', doc.attr('outfilesuffix')
    output = invoker.read_output
    assert_xpath '/article', output, 1
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

  test 'should set attribute with value' do
    invoker = invoke_cli_to_buffer %w(-a idprefix=id -s -o -)
    doc = invoker.document
    assert_equal 'id', doc.attr('idprefix')
    output = invoker.read_output
    assert_xpath '//h2[@id="idsection_a"]', output, 1
  end

  test 'should set attribute with no value' do
    invoker = invoke_cli_to_buffer %w(-a icons -s -o -)
    doc = invoker.document
    assert_equal 1, doc.attr('icons')
    output = invoker.read_output
    assert_xpath '//*[@class="admonitionblock"]//img[@alt="Note"]', output, 1
  end

  test 'should unset attribute ending in bang' do
    invoker = invoke_cli_to_buffer %w(-a sectids! -s -o -)
    doc = invoker.document
    assert !doc.attr?('sectids')
    output = invoker.read_output
    # leave the count loose in case we add more sections
    assert_xpath '//h2[not(@id)]', output
  end

  test 'should set safe mode if specified' do
    invoker = invoke_cli_to_buffer %w(--safe -o /dev/null)
    doc = invoker.document
    assert_equal Asciidoctor::SafeMode::SAFE, doc.safe
  end

  test 'should set safe mode to specified level if specified' do
    invoker = invoke_cli_to_buffer %w(-S safe -o /dev/null)
    doc = invoker.document
    assert_equal Asciidoctor::SafeMode::SAFE, doc.safe
  end

  test 'should set eRuby impl if specified' do
    invoker = invoke_cli_to_buffer %w(--eruby erubis -o /dev/null)
    doc = invoker.document
    assert_equal 'erubis', doc.instance_variable_get('@options')[:eruby]
  end

end
