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
end
