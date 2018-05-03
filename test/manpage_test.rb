# encoding: UTF-8
unless defined? ASCIIDOCTOR_PROJECT_DIR
  $: << File.dirname(__FILE__); $:.uniq!
  require 'test_helper'
end

SAMPLE_MANPAGE_HEADER = <<-EOS.chomp
= command (1)
Author Name
:doctype: manpage
:man manual: Command Manual
:man source: Command 1.2.3

== NAME

command - does stuff

== SYNOPSIS

*command* [_OPTION_]... _FILE_...

== DESCRIPTION
EOS

context 'Manpage' do
  context 'Configuration' do
    test 'should set proper manpage-related attributes' do
      input = SAMPLE_MANPAGE_HEADER
      doc = Asciidoctor.load input, :backend => :manpage
      assert_equal 'man', doc.attributes['filetype']
      assert_equal '', doc.attributes['filetype-man']
      assert_equal '1', doc.attributes['manvolnum']
      assert_equal '.1', doc.attributes['outfilesuffix']
      assert_equal 'command', doc.attributes['manname']
      assert_equal 'command', doc.attributes['mantitle']
      assert_equal 'does stuff', doc.attributes['manpurpose']
      assert_equal 'command', doc.attributes['docname']
    end

    test 'should output multiple mannames in NAME section' do
      input = SAMPLE_MANPAGE_HEADER.sub(/^command - /, 'command, alt_command - ')
      output = Asciidoctor.convert input, :backend => :manpage, :header_footer => true
      assert_includes output.lines, %(command, alt_command \\- does stuff\n)
    end

    test 'should skip line comments in NAME section' do
      input = <<-EOS
= foobar (1)
Author Name
:doctype: manpage
:man manual: Foo Bar Manual
:man source: Foo Bar 1.0

== NAME

// follows the form `name - description`
foobar - puts some foo on the bar
// a little bit of this, a little bit of that

== SYNOPSIS

*foobar* [_OPTIONS_]...

== DESCRIPTION

When you need to put some foo on the bar.
      EOS

      doc = Asciidoctor.load input, :backend => :manpage, :header_footer => true
      assert_equal 'puts some foo on the bar', (doc.attr 'manpurpose')
    end

    test 'should define default linkstyle' do
      input = SAMPLE_MANPAGE_HEADER
      output = Asciidoctor.convert input, :backend => :manpage, :header_footer => true
      assert_includes output.lines, %(.  LINKSTYLE blue R < >\n)
    end

    test 'should use linkstyle defined by man-linkstyle attribute' do
      input = SAMPLE_MANPAGE_HEADER
      output = Asciidoctor.convert input, :backend => :manpage, :header_footer => true,
          :attributes => { 'man-linkstyle' => 'cyan B \[fo] \[fc]' }
      assert_includes output.lines, %(.  LINKSTYLE cyan B \\[fo] \\[fc]\n)
    end

    test 'should require specialchars in value of man-linkstyle attribute defined in document to be escaped' do
      input = %(:man-linkstyle: cyan R < >
#{SAMPLE_MANPAGE_HEADER})
      output = Asciidoctor.convert input, :backend => :manpage, :header_footer => true
      assert_includes output.lines, %(.  LINKSTYLE cyan R &lt; &gt;\n)

      input = %(:man-linkstyle: pass:[cyan R < >]
#{SAMPLE_MANPAGE_HEADER})
      output = Asciidoctor.convert input, :backend => :manpage, :header_footer => true
      assert_includes output.lines, %(.  LINKSTYLE cyan R < >\n)
    end
  end

  context 'Manify' do
    test 'should unescape literal ampersand' do
      input = %(#{SAMPLE_MANPAGE_HEADER}

(C) & (R) are translated to character references, but not the &.)
      output = Asciidoctor.convert input, :backend => :manpage
      assert_equal '\\(co & \\(rg are translated to character references, but not the &.', output.lines.entries.last.chomp
    end

    test 'should replace em dashes' do
      input = %(#{SAMPLE_MANPAGE_HEADER}

go -- to

go--to)
      output = Asciidoctor.convert input, :backend => :manpage
      assert_includes output, 'go \\(em to'
      assert_includes output, 'go\\(emto'
    end

    test 'should escape lone period' do
      input = %(#{SAMPLE_MANPAGE_HEADER}

.)
      output = Asciidoctor.convert input, :backend => :manpage
      assert_equal '\&.', output.lines.entries.last.chomp
    end

    test 'should escape raw macro' do
      input = %(#{SAMPLE_MANPAGE_HEADER}

AAA this line of text should be show
.if 1 .nx
BBB this line and the one above it should be visible)

      output = Asciidoctor.convert input, :backend => :manpage
      assert_equal '\&.if 1 .nx', output.lines.entries[-2].chomp
    end
  end

  context 'Backslash' do
    test 'should not escape spaces for empty manual or source fields' do
      input = SAMPLE_MANPAGE_HEADER.lines.select {|l| !l.start_with?(':man ') }
      output = Asciidoctor.convert input, :backend => :manpage, :header_footer => true
      assert_match ' Manual: \ \&', output
      assert_match ' Source: \ \&', output
      assert_match(/^\.TH "COMMAND" .* "\\ \\&" "\\ \\&"$/, output)
    end

    test 'should preserve backslashes in escape sequences' do
      input = %(#{SAMPLE_MANPAGE_HEADER}

"`hello`" '`goodbye`' *strong* _weak_ `even`)
      output = Asciidoctor.convert input, :backend => :manpage
      assert_equal '\(lqhello\(rq \(oqgoodbye\(cq \fBstrong\fP \fIweak\fP \f(CReven\fP', output.lines.entries.last.chomp
    end

    test 'should escape backslashes in content' do
      input = %(#{SAMPLE_MANPAGE_HEADER}

\\.foo \\ bar\\
baz)
      output = Asciidoctor.convert input, :backend => :manpage
      assert_equal '\(rs.foo \(rs bar\(rs', output.lines.entries[-2].chomp
    end

    test 'should escape literal escape sequence' do
      input = %(#{SAMPLE_MANPAGE_HEADER}

 \\fB makes text bold)
      output = Asciidoctor.convert input, :backend => :manpage
      assert_match '\(rsfB makes text bold', output
    end

    test 'should preserve inline breaks' do
      input = %(#{SAMPLE_MANPAGE_HEADER}

Before break. +
After break.)
      output = Asciidoctor.convert input, :backend => :manpage
      assert_equal 'Before break.
.br
After break.', output.lines.entries[-3..-1].join
    end
  end

  context 'URL macro' do
    test 'should not leave blank line before URL macro' do
      input = %(#{SAMPLE_MANPAGE_HEADER}
First paragraph.

http://asciidoc.org[AsciiDoc])
      output = Asciidoctor.convert input, :backend => :manpage
      assert_equal '.sp
First paragraph.
.sp
.URL "http://asciidoc.org" "AsciiDoc" ""', output.lines.entries[-4..-1].join
    end

    test 'should not swallow content following URL' do
      input = %(#{SAMPLE_MANPAGE_HEADER}

http://asciidoc.org[AsciiDoc] can be used to create man pages.)
      output = Asciidoctor.convert input, :backend => :manpage
      assert_equal '.URL "http://asciidoc.org" "AsciiDoc" " "
can be used to create man pages.', output.lines.entries[-2..-1].join
    end

    test 'should pass adjacent character as final argument of URL macro' do
      input = %(#{SAMPLE_MANPAGE_HEADER}

This is http://asciidoc.org[AsciiDoc].)
      output = Asciidoctor.convert input, :backend => :manpage
      assert_equal 'This is \c
.URL "http://asciidoc.org" "AsciiDoc" "."', output.lines.entries[-2..-1].join
    end

    test 'should pass adjacent character as final argument of URL macro and move trailing content to next line' do
      input = %(#{SAMPLE_MANPAGE_HEADER}

This is http://asciidoc.org[AsciiDoc], which can be used to write content.)
      output = Asciidoctor.convert input, :backend => :manpage
      assert_equal 'This is \c
.URL "http://asciidoc.org" "AsciiDoc" ","
which can be used to write content.', output.lines.entries[-3..-1].join
    end

    test 'should not leave blank lines between URLs on contiguous lines of input' do
      input = %(#{SAMPLE_MANPAGE_HEADER}

The corresponding implementations are
http://clisp.sf.net[CLISP],
http://ccl.clozure.com[Clozure CL],
http://cmucl.org[CMUCL],
http://ecls.sf.net[ECL],
and http://sbcl.sf.net[SBCL].)
      output = Asciidoctor.convert input, :backend => :manpage
      assert_equal '.sp
The corresponding implementations are
.URL "http://clisp.sf.net" "CLISP" ","
.URL "http://ccl.clozure.com" "Clozure CL" ","
.URL "http://cmucl.org" "CMUCL" ","
.URL "http://ecls.sf.net" "ECL" ","
and \c
.URL "http://sbcl.sf.net" "SBCL" "."', output.lines.entries[-8..-1].join
    end

    test 'should not leave blank lines between URLs on same line of input' do
      input = %(#{SAMPLE_MANPAGE_HEADER}

The corresponding implementations are http://clisp.sf.net[CLISP], http://ccl.clozure.com[Clozure CL], http://cmucl.org[CMUCL], http://ecls.sf.net[ECL], and http://sbcl.sf.net[SBCL].)
      output = Asciidoctor.convert input, :backend => :manpage
      assert_equal '.sp
The corresponding implementations are \c
.URL "http://clisp.sf.net" "CLISP" ","
.URL "http://ccl.clozure.com" "Clozure CL" ","
.URL "http://cmucl.org" "CMUCL" ","
.URL "http://ecls.sf.net" "ECL" ","
and
.URL "http://sbcl.sf.net" "SBCL" "."', output.lines.entries[-8..-1].join
    end

    test 'should not insert space between link and non-whitespace characters surrounding it' do
      input = %(#{SAMPLE_MANPAGE_HEADER}

Please search |link:http://discuss.asciidoctor.org[the forums]| before asking.)
      output = Asciidoctor.convert input, :backend => :manpage
      assert_equal '.sp
Please search |\c
.URL "http://discuss.asciidoctor.org" "the forums" "|"
before asking.', output.lines.entries[-4..-1].join
    end

    test 'should be able to use monospaced text inside a link' do
      input = %(#{SAMPLE_MANPAGE_HEADER}

Enter the link:cat[`cat`] command.)
      output = Asciidoctor.convert input, :backend => :manpage
      assert_equal '.sp
Enter the \c
.URL "cat" "\f(CRcat\fP" " "
command.', output.lines.entries[-4..-1].join
    end
  end

  context 'MTO macro' do
    test 'should convert inline email macro into MTO macro' do
      input = %(#{SAMPLE_MANPAGE_HEADER}
First paragraph.

mailto:doc@example.org[Contact the doc])
      output = Asciidoctor.convert input, :backend => :manpage
      assert_equal '.sp
First paragraph.
.sp
.MTO "doc\\(atexample.org" "Contact the doc" ""', output.lines.entries[-4..-1].join
    end

    test 'should set text of MTO macro to blank for implicit email' do
      input = %(#{SAMPLE_MANPAGE_HEADER}
Bugs fixed daily by doc@example.org.)
      output = Asciidoctor.convert input, :backend => :manpage
      assert output.end_with? 'Bugs fixed daily by \\c
.MTO "doc\\(atexample.org" "" "."'
    end
  end

  context 'Table' do
    test 'should create header, body, and footer rows in correct order' do
      input = %(#{SAMPLE_MANPAGE_HEADER}

[%header%footer]
|===
|Header
|Body 1
|Body 2
|Footer
|===)
      output = Asciidoctor.convert input, :backend => :manpage
      assert output.end_with? 'allbox tab(:);
lt.
T{
.sp
Header
T}
T{
.sp
Body 1
T}
T{
.sp
Body 2
T}
T{
.sp
Footer
T}
.TE
.sp'
    end

    test 'should manify normal table cell content' do
      input = %(#{SAMPLE_MANPAGE_HEADER}

|===
|*Col A* |_Col B_

|*bold* |`mono`
|_italic_ | #mark#
|===)
      output = Asciidoctor.convert input, :backend => :manpage
      refute_match(/<\/?BOUNDARY>/, output)
    end

    test 'should manify table title' do
      input = %(#{SAMPLE_MANPAGE_HEADER}

.Table of options
|===
| Name | Description | Default

| dim
| dimension of the object
| 3
|===)
      output = Asciidoctor.convert input, :backend => :manpage
      assert output.end_with? '.it 1 an-trap
.nr an-no-space-flag 1
.nr an-break-flag 1
.br
.B Table 1. Table of options
.TS
allbox tab(:);
lt lt lt.
T{
.sp
Name
T}:T{
.sp
Description
T}:T{
.sp
Default
T}
T{
.sp
dim
T}:T{
.sp
dimension of the object
T}:T{
.sp
3
T}
.TE
.sp'
    end

    test 'should manify and preserve whitespace in literal table cell' do
      input = %(#{SAMPLE_MANPAGE_HEADER}

|===
|a l|b
c    _d_
.
|===)
      output = Asciidoctor.convert input, :backend => :manpage
      assert output.end_with? '.TS
allbox tab(:);
lt lt.
T{
.sp
a
T}:T{
.sp
.nf
b
c    _d_
\\&.
.fi
T}
.TE
.sp'
    end

    test 'should manify and preserve whitespace in verse table cell' do
      input = %(#{SAMPLE_MANPAGE_HEADER}

|===
|a v|b
c    _d_
.
|===)
      output = Asciidoctor.convert input, :backend => :manpage
      assert output.end_with? '.TS
allbox tab(:);
lt lt.
T{
.sp
a
T}:T{
.sp
.nf
b
c    \\fId\\fP
\\&.
.fi
T}
.TE
.sp'
    end
  end

  context 'Images' do
    test 'should replace inline image with alt text' do
      input = %(#{SAMPLE_MANPAGE_HEADER}

The Magic 8 Ball says image:signs-point-to-yes.jpg[].)
      output = Asciidoctor.convert input, :backend => :manpage
      assert_includes output, 'The Magic 8 Ball says [signs point to yes].'
    end

    test 'should place link after alt text for inline image if link is defined' do
      input = %(#{SAMPLE_MANPAGE_HEADER}

The Magic 8 Ball says image:signs-point-to-yes.jpg[link=https://en.wikipedia.org/wiki/Magic_8-Ball].)
      output = Asciidoctor.convert input, :backend => :manpage
      assert_includes output, 'The Magic 8 Ball says [signs point to yes] <https://en.wikipedia.org/wiki/Magic_8\-Ball>.'
    end
  end

  context 'Callout List' do
    test 'should generate callout list using proper formatting commands' do
      input = %(#{SAMPLE_MANPAGE_HEADER}

----
$ gem install asciidoctor # <1>
----
<1> Installs the asciidoctor gem from RubyGems.org)
      output = Asciidoctor.convert input, :backend => :manpage
      assert output.end_with? '.TS
tab(:);
r lw(\n(.lu*75u/100u).
\fB(1)\fP\h\'-2n\':T{
Installs the asciidoctor gem from RubyGems.org
T}
.TE'
    end
  end

  context 'Environment' do
    test 'should use SOURCE_DATE_EPOCH as modified time of input file and local time' do
      old_source_date_epoch = ENV.delete 'SOURCE_DATE_EPOCH'
      begin
        ENV['SOURCE_DATE_EPOCH'] = '1234123412'
        output = Asciidoctor.convert SAMPLE_MANPAGE_HEADER, :backend => :manpage, :header_footer => true
        assert_match(/Date: 2009-02-08/, output)
        assert_match(/^\.TH "COMMAND" "1" "2009-02-08" "Command 1.2.3" "Command Manual"$/, output)
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
        Asciidoctor.convert SAMPLE_MANPAGE_HEADER, :backend => :manpage, :header_footer => true
        assert false
      rescue
        assert true
      ensure
        if old_source_date_epoch
          ENV['SOURCE_DATE_EPOCH'] = old_source_date_epoch
        else
          ENV.delete 'SOURCE_DATE_EPOCH'
        end
      end
    end
  end
end
