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
    test 'should define default linkstyle' do
      input = SAMPLE_MANPAGE_HEADER
      output = Asciidoctor.convert input, :backend => :manpage, :header_footer => true
      assert_match(/^\.LINKSTYLE blue R < >$/, output)
    end

    test 'should use linkstyle defined by man-linkstyle attribute' do
      input = SAMPLE_MANPAGE_HEADER
      output = Asciidoctor.convert input, :backend => :manpage, :header_footer => true,
          :attributes => { 'man-linkstyle' => 'cyan B \[fo] \[fc]' }
      assert_match(/^\.LINKSTYLE cyan B \\\[fo\] \\\[fc\]$/, output)
    end
  end

  context 'Manify' do
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
      assert_equal '\(lqhello\(rq \(oqgoodbye\(cq \fBstrong\fP \fIweak\fP \f[CR]even\fP', output.lines.entries.last.chomp
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
end
