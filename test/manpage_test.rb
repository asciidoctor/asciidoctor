# frozen_string_literal: true
require_relative 'test_helper'

context 'Manpage' do
  SAMPLE_MANPAGE_HEADER = <<~'EOS'.chop
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

  context 'Configuration' do
    test 'should set proper manpage-related attributes' do
      input = SAMPLE_MANPAGE_HEADER
      doc = Asciidoctor.load input, backend: :manpage
      assert_equal 'man', doc.attributes['filetype']
      assert_equal '', doc.attributes['filetype-man']
      assert_equal '1', doc.attributes['manvolnum']
      assert_equal '.1', doc.attributes['outfilesuffix']
      assert_equal 'command', doc.attributes['manname']
      assert_equal 'command', doc.attributes['mantitle']
      assert_equal 'does stuff', doc.attributes['manpurpose']
      assert_equal 'command', doc.attributes['docname']
    end

    test 'should not escape hyphen when printing manname in NAME section' do
      input = SAMPLE_MANPAGE_HEADER.sub(/^command - /, 'git-describe - ')
      output = Asciidoctor.convert input, backend: :manpage, standalone: true
      assert_includes output, %(\n.SH "NAME"\ngit-describe \\- does stuff\n)
    end

    test 'should output multiple mannames in NAME section' do
      input = SAMPLE_MANPAGE_HEADER.sub(/^command - /, 'command, alt_command - ')
      output = Asciidoctor.convert input, backend: :manpage, standalone: true
      assert_includes output.lines, %(command, alt_command \\- does stuff\n)
    end

    test 'should substitute attributes in manname and manpurpose in NAME section' do
      input = <<~'EOS'
      = {cmdname} (1)
      Author Name
      :doctype: manpage
      :man manual: Foo Bar Manual
      :man source: Foo Bar 1.0

      == NAME

      {cmdname} - {cmdname} puts the foo in your bar
      EOS

      doc = Asciidoctor.load input, backend: :manpage, standalone: true, attributes: { 'cmdname' => 'foobar' }
      assert_equal 'foobar', (doc.attr 'manname')
      assert_equal ['foobar'], (doc.attr 'mannames')
      assert_equal 'foobar puts the foo in your bar', (doc.attr 'manpurpose')
      assert_equal 'foobar', (doc.attr 'docname')
    end

    test 'should not parse NAME section if manname and manpurpose attributes are set' do
      input = <<~'EOS'
      = foobar (1)
      Author Name
      :doctype: manpage
      :man manual: Foo Bar Manual
      :man source: Foo Bar 1.0

      == SYNOPSIS

      *foobar* [_OPTIONS_]...

      == DESCRIPTION

      When you need to put some foo on the bar.
      EOS

      attrs = { 'manname' => 'foobar', 'manpurpose' => 'puts some foo on the bar' }
      doc = Asciidoctor.load input, backend: :manpage, standalone: true, attributes: attrs
      assert_equal 'foobar', (doc.attr 'manname')
      assert_equal ['foobar'], (doc.attr 'mannames')
      assert_equal 'puts some foo on the bar', (doc.attr 'manpurpose')
      assert_equal 'SYNOPSIS', doc.sections[0].title
    end

    test 'should normalize whitespace and skip line comments before and inside NAME section' do
      input = <<~'EOS'
      = foobar (1)
      Author Name
      :doctype: manpage
      :man manual: Foo Bar Manual
      :man source: Foo Bar 1.0

      // this is the name section
      == NAME

      // it follows the form `name - description`
      foobar - puts some foo
       on the bar
      // a little bit of this, a little bit of that

      == SYNOPSIS

      *foobar* [_OPTIONS_]...

      == DESCRIPTION

      When you need to put some foo on the bar.
      EOS

      doc = Asciidoctor.load input, backend: :manpage, standalone: true
      assert_equal 'puts some foo on the bar', (doc.attr 'manpurpose')
    end

    test 'should parse malformed document with warnings' do
      input = 'garbage in'
      using_memory_logger do |logger|
        doc = Asciidoctor.load input, backend: :manpage, standalone: true, attributes: { 'docname' => 'cmd' }
        assert_equal 'cmd', doc.attr('manname')
        assert_equal ['cmd'], doc.attr('mannames')
        assert_equal '.1', doc.attr('outfilesuffix')
        output = doc.convert
        refute logger.messages.empty?
        assert_includes output, 'Title: cmd'
        assert output.end_with?('garbage in')
      end
    end

    test 'should warn if document title is non-conforming' do
      input = <<~'EOS'
      = command

      == Name

      command - does stuff
      EOS

      using_memory_logger do |logger|
        document_from_string input, backend: :manpage
        assert_message logger, :ERROR, '<stdin>: line 1: non-conforming manpage title', Hash
      end
    end

    test 'should warn if first section is not name section' do
      input = <<~'EOS'
      = command(1)

      == Synopsis

      Does stuff.
      EOS

      using_memory_logger do |logger|
        doc = document_from_string input, backend: :manpage
        assert_message logger, :ERROR, '<stdin>: line 3: non-conforming name section body', Hash
        refute_nil doc.sections[0]
        assert_equal 'Synopsis', doc.sections[0].title
      end
    end

    test 'should break circular reference in section title' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      [#a]
      == A <<b>>

      [#b]
      == B <<a>>
      EOS

      output = Asciidoctor.convert input, backend: :manpage
      assert_match %r/^\.SH "A B \[A\]"$/, output
      assert_match %r/^\.SH "B \[A\]"$/, output
    end

    test 'should define default linkstyle' do
      input = SAMPLE_MANPAGE_HEADER
      output = Asciidoctor.convert input, backend: :manpage, standalone: true
      assert_includes output.lines, %(.  LINKSTYLE blue R < >\n)
    end

    test 'should use linkstyle defined by man-linkstyle attribute' do
      input = SAMPLE_MANPAGE_HEADER
      output = Asciidoctor.convert input, backend: :manpage, standalone: true, attributes: { 'man-linkstyle' => 'cyan B \[fo] \[fc]' }
      assert_includes output.lines, %(.  LINKSTYLE cyan B \\[fo] \\[fc]\n)
    end

    test 'should require specialchars in value of man-linkstyle attribute defined in document to be escaped' do
      input = <<~EOS.chop
      :man-linkstyle: cyan R < >
      #{SAMPLE_MANPAGE_HEADER}
      EOS
      output = Asciidoctor.convert input, backend: :manpage, standalone: true
      assert_includes output.lines, %(.  LINKSTYLE cyan R &lt; &gt;\n)

      input = <<~EOS.chop
      :man-linkstyle: pass:[cyan R < >]
      #{SAMPLE_MANPAGE_HEADER}
      EOS
      output = Asciidoctor.convert input, backend: :manpage, standalone: true
      assert_includes output.lines, %(.  LINKSTYLE cyan R < >\n)
    end
  end

  context 'Manify' do
    test 'should unescape literal ampersand' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      (C) & (R) are translated to character references, but not the &.
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert_equal '\\(co & \\(rg are translated to character references, but not the &.', output.lines.last.chomp
    end

    test 'should replace numeric character reference for plus' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      A {plus} B
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert_equal 'A + B', output.lines.last.chomp
    end

    test 'should replace numeric character reference for degree sign' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      0{deg} is freezing
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert_equal '0\(de is freezing', output.lines.last.chomp
    end

    test 'should replace em dashes' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      go -- to

      go--to
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert_includes output, 'go \\(em to'
      assert_includes output, 'go\\(emto'
    end

    test 'should replace quotes' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      'command'
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert_includes output, '\*(Aqcommand\*(Aq'
    end

    test 'should escape lone period' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      .
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert_equal '\&.', output.lines.last.chomp
    end

    test 'should escape raw macro' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      AAA this line of text should be show
      .if 1 .nx
      BBB this line and the one above it should be visible
      EOS

      output = Asciidoctor.convert input, backend: :manpage
      assert_equal '\&.if 1 .nx', output.lines[-2].chomp
    end

    test 'should escape ellipsis at start of line' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      -x::
	Ao gravar o commit, acrescente uma linha que diz "(cherry picked from commit
	...)" à mensagem de commit original para indicar qual commit esta mudança
	foi escolhida. Isso é feito apenas para picaretas de cereja sem conflitos.
	EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert_equal '\&...', output.lines[-3][0..4].chomp
    end

    test 'should not escape ellipsis in the middle of a line' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      -x::
	Ao gravar o commit, acrescente uma linha que diz
	"(cherry picked from commit...)" à mensagem de commit
	 original para indicar qual commit esta mudança
	foi escolhida. Isso é feito apenas para picaretas
	de cereja sem conflitos.
	EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert(output.lines[-5].include? 'commit...')
    end

    test 'should normalize whitespace in a paragraph' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      Oh, here it goes again
        I should have known,
          should have known,
      should have known again
      EOS

      output = Asciidoctor.convert input, backend: :manpage
      assert_includes output, %(Oh, here it goes again\nI should have known,\nshould have known,\nshould have known again)
    end

    test 'should normalize whitespace in a list item' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      * Oh, here it goes again
          I should have known,
        should have known,
      should have known again
      EOS

      output = Asciidoctor.convert input, backend: :manpage
      assert_includes output, %(Oh, here it goes again\nI should have known,\nshould have known,\nshould have known again)
    end

    test 'should honor start attribute on ordered list' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      [start=5]
      . five
      . six
      EOS

      output = Asciidoctor.convert input, backend: :manpage
      assert_match %r/IP " 5\.".*five/m, output
      assert_match %r/IP " 6\.".*six/m, output
    end

    test 'should collapse whitespace in the man manual and man source' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      Describe this thing.
      EOS

      output = Asciidoctor.convert input, backend: :manpage, standalone: true, attributes: {
        'manmanual' => %(General\nCommands\nManual),
        'mansource' => %(Control\nAll\nThe\nThings\n5.0),
      }
      assert_includes output, 'Manual: General Commands Manual'
      assert_includes output, 'Source: Control All The Things 5.0'
      assert_includes output, '"Control All The Things 5.0" "General Commands Manual"'
    end

    test 'should uppercase section titles without mangling formatting macros' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      does stuff

      == "`Main`" _<Options>_
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert_includes output, '.SH "\(lqMAIN\(rq \fI<OPTIONS>\fP"'
    end
  end

  context 'Backslash' do
    test 'should not escape spaces for empty manual or source fields' do
      input = SAMPLE_MANPAGE_HEADER.lines.reject {|l| l.start_with? ':man ' }
      output = Asciidoctor.convert input, backend: :manpage, standalone: true
      assert_match ' Manual: \ \&', output
      assert_match ' Source: \ \&', output
      assert_match(/^\.TH "COMMAND" .* "\\ \\&" "\\ \\&"$/, output)
    end

    test 'should preserve backslashes in escape sequences' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      "`hello`" '`goodbye`' *strong* _weak_ `even`
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert_equal '\(lqhello\(rq \(oqgoodbye\(cq \fBstrong\fP \fIweak\fP \f(CReven\fP', output.lines.last.chomp
    end

    test 'should preserve literal backslashes in content' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      \\.foo \\ bar \\\\ baz\\
      more
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert_equal '\(rs.foo \(rs bar \(rs\(rs baz\(rs', output.lines[-2].chomp
    end

    test 'should escape literal escape sequence' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

       \\fB makes text bold
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert_match '\(rsfB makes text bold', output
    end

    test 'should preserve inline breaks' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      Before break. +
      After break.
      EOS
      expected = <<~'EOS'.chop
      Before break.
      .br
      After break.
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert_equal expected, output.lines[-3..-1].join
    end
  end

  context 'URL macro' do
    test 'should not leave blank line before URL macro' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}
      First paragraph.

      http://asciidoc.org[AsciiDoc]
      EOS
      expected = <<~'EOS'.chop
      .sp
      First paragraph.
      .sp
      .URL "http://asciidoc.org" "AsciiDoc" ""
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert_equal expected, output.lines[-4..-1].join
    end

    test 'should not swallow content following URL' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      http://asciidoc.org[AsciiDoc] can be used to create man pages.
      EOS
      expected = <<~'EOS'.chop
      .URL "http://asciidoc.org" "AsciiDoc" ""
      can be used to create man pages.
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert_equal expected, output.lines[-2..-1].join
    end

    test 'should pass adjacent character as final argument of URL macro' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      This is http://asciidoc.org[AsciiDoc].
      EOS
      expected = <<~'EOS'.chop
      This is \c
      .URL "http://asciidoc.org" "AsciiDoc" "."
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert_equal expected, output.lines[-2..-1].join
    end

    test 'should pass adjacent character as final argument of URL macro and move trailing content to next line' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      This is http://asciidoc.org[AsciiDoc], which can be used to write content.
      EOS
      expected = <<~'EOS'.chop
      This is \c
      .URL "http://asciidoc.org" "AsciiDoc" ","
      which can be used to write content.
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert_equal expected, output.lines[-3..-1].join
    end

    test 'should not leave blank lines between URLs on contiguous lines of input' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      The corresponding implementations are
      http://clisp.sf.net[CLISP],
      http://ccl.clozure.com[Clozure CL],
      http://cmucl.org[CMUCL],
      http://ecls.sf.net[ECL],
      and http://sbcl.sf.net[SBCL].
      EOS
      expected = <<~'EOS'.chop
      .sp
      The corresponding implementations are
      .URL "http://clisp.sf.net" "CLISP" ","
      .URL "http://ccl.clozure.com" "Clozure CL" ","
      .URL "http://cmucl.org" "CMUCL" ","
      .URL "http://ecls.sf.net" "ECL" ","
      and \c
      .URL "http://sbcl.sf.net" "SBCL" "."
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert_equal expected, output.lines[-8..-1].join
    end

    test 'should not leave blank lines between URLs on same line of input' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      The corresponding implementations are http://clisp.sf.net[CLISP], http://ccl.clozure.com[Clozure CL], http://cmucl.org[CMUCL], http://ecls.sf.net[ECL], and http://sbcl.sf.net[SBCL].
      EOS
      expected = <<~'EOS'.chop
      .sp
      The corresponding implementations are \c
      .URL "http://clisp.sf.net" "CLISP" ","
      .URL "http://ccl.clozure.com" "Clozure CL" ","
      .URL "http://cmucl.org" "CMUCL" ","
      .URL "http://ecls.sf.net" "ECL" ","
      and
      .URL "http://sbcl.sf.net" "SBCL" "."
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert_equal expected, output.lines[-8..-1].join
    end

    test 'should not insert space between link and non-whitespace characters surrounding it' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      Please search |link:http://discuss.asciidoctor.org[the forums]| before asking.
      EOS
      expected = <<~'EOS'.chop
      .sp
      Please search |\c
      .URL "http://discuss.asciidoctor.org" "the forums" "|"
      before asking.
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert_equal expected, output.lines[-4..-1].join
    end

    test 'should be able to use monospaced text inside a link' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      Enter the link:cat[`cat`] command.
      EOS
      expected = <<~'EOS'.chop
      .sp
      Enter the \c
      .URL "cat" "\f(CRcat\fP" ""
      command.
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert_equal expected, output.lines[-4..-1].join
    end
  end

  context 'MTO macro' do
    test 'should convert inline email macro into MTO macro' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}
      First paragraph.

      mailto:doc@example.org[Contact the doc]
      EOS
      expected = <<~'EOS'.chop
      .sp
      First paragraph.
      .sp
      .MTO "doc\(atexample.org" "Contact the doc" ""
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert_equal expected, output.lines[-4..-1].join
    end

    test 'should set text of MTO macro to blank for implicit email' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}
      Bugs fixed daily by doc@example.org.
      EOS
      expected_coda = <<~'EOS'.chop
      Bugs fixed daily by \c
      .MTO "doc\(atexample.org" "" "."
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert output.end_with? expected_coda
    end
  end

  context 'Table' do
    test 'should create header, body, and footer rows in correct order' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      [%header%footer]
      |===
      |Header
      |Body 1
      |Body 2
      |Footer
      |===
      EOS
      expected_coda = <<~'EOS'.chop
      allbox tab(:);
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
      .sp
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert output.end_with? expected_coda
    end

    test 'should manify normal table cell content' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      |===
      |*Col A* |_Col B_

      |*bold* |`mono`
      |_italic_ | #mark#
      |===
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      refute_match(/<\/?BOUNDARY>/, output)
    end

    test 'should manify table title' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      .Table of options
      |===
      | Name | Description | Default

      | dim
      | dimension of the object
      | 3
      |===
      EOS
      expected_coda = <<~'EOS'.chop
      .it 1 an-trap
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
      .sp
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert output.end_with? expected_coda
    end

    test 'should manify and preserve whitespace in literal table cell' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      |===
      |a l|b
      c    _d_
      .
      |===
      EOS
      expected_coda = <<~'EOS'.chop
      .TS
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
      \&.
      .fi
      T}
      .TE
      .sp
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert output.end_with? expected_coda
    end
  end

  context 'Images' do
    test 'should replace block image with alt text enclosed in square brackets' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      Behold the wisdom of the Magic 8 Ball!

      image::signs-point-to-yes.jpg[]
      EOS

      output = Asciidoctor.convert input, backend: :manpage
      assert output.end_with? %(\n.sp\n[signs point to yes])
    end

    test 'should replace inline image with alt text enclosed in square brackets' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      The Magic 8 Ball says image:signs-point-to-yes.jpg[].
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert_includes output, 'The Magic 8 Ball says [signs point to yes].'
    end

    test 'should place link after alt text for inline image if link is defined' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      The Magic 8 Ball says image:signs-point-to-yes.jpg[link=https://en.wikipedia.org/wiki/Magic_8-Ball].
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert_includes output, 'The Magic 8 Ball says [signs point to yes] <https://en.wikipedia.org/wiki/Magic_8\-Ball>.'
    end

    test 'should reference image with title usign styled xref' do
      input = <<~EOS.chomp
      #{SAMPLE_MANPAGE_HEADER}

      To get your fortune, see <<magic-8-ball>>.

      .Magic 8-Ball
      [#magic-8-ball]
      image::signs-point-to-yes.jpg[]
      EOS
      output = Asciidoctor.convert input, backend: :manpage, attributes: { 'xrefstyle' => 'full' }
      lines = output.lines.map(&:chomp)
      assert_includes lines, 'To get your fortune, see Figure 1, \(lqMagic 8\-Ball\(rq.'
      assert_includes lines, '.B Figure 1. Magic 8\-Ball'
    end
  end

  context 'Quote Block' do
    test 'should indent quote block' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      [,James Baldwin]
      ____
      Not everything that is faced can be changed.
      But nothing can be changed until it is faced.
      ____
      EOS
      expected_coda = <<~'EOS'.chop
      .RS 3
      .ll -.6i
      .sp
      Not everything that is faced can be changed.
      But nothing can be changed until it is faced.
      .br
      .RE
      .ll
      .RS 5
      .ll -.10i
      \(em James Baldwin
      .RE
      .ll
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert output.end_with? expected_coda
    end
  end

  context 'Verse Block' do
    test 'should preserve hard line breaks in verse block' do
      input = SAMPLE_MANPAGE_HEADER.lines
      synopsis_idx = input.find_index {|it| it == %(== SYNOPSIS\n) } + 2
      input[synopsis_idx..synopsis_idx] = <<~'EOS'.lines
      [verse]
      _command_ [_OPTION_]... _FILE_...
      EOS
      input = <<~EOS.chop
      #{input.join}

      description
      EOS
      expected_coda = <<~'EOS'.chop
      .SH "SYNOPSIS"
      .sp
      .nf
      \fIcommand\fP [\fIOPTION\fP]... \fIFILE\fP...
      .fi
      .br
      .SH "DESCRIPTION"
      .sp
      description
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert output.end_with? expected_coda
    end
  end

  context 'Callout List' do
    test 'should generate callout list using proper formatting commands' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      ----
      $ gem install asciidoctor # <1>
      ----
      <1> Installs the asciidoctor gem from RubyGems.org
      EOS
      expected_coda = <<~'EOS'.chop
      .TS
      tab(:);
      r lw(\n(.lu*75u/100u).
      \fB(1)\fP\h'-2n':T{
      Installs the asciidoctor gem from RubyGems.org
      T}
      .TE
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert output.end_with? expected_coda
    end
  end

  context 'Page breaks' do
    test 'should insert page break at location of page break macro' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      == Section With Break

      before break

      <<<

      after break
      EOS
      expected_coda = <<~'EOS'.chop
      .SH "SECTION WITH BREAK"
      .sp
      before break
      .bp
      .sp
      after break
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert output.end_with? expected_coda
    end
  end

  context 'UI macros' do
    test 'should enclose button in square brackets and format as bold' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      == UI Macros

      btn:[Save]
      EOS
      expected_coda = <<~'EOS'.chop
      .SH "UI MACROS"
      .sp
      \fB[\0Save\0]\fP
      EOS
      output = Asciidoctor.convert input, backend: :manpage, attributes: { 'experimental' => '' }
      assert output.end_with? expected_coda
    end

    test 'should format single key in monospaced text' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      == UI Macros

      kbd:[Enter]
      EOS
      expected_coda = <<~'EOS'.chop
      .SH "UI MACROS"
      .sp
      \f(CREnter\fP
      EOS
      output = Asciidoctor.convert input, backend: :manpage, attributes: { 'experimental' => '' }
      assert output.end_with? expected_coda
    end

    test 'should format each key in sequence as monospaced text separated by +' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      == UI Macros

      kbd:[Ctrl,s]
      EOS
      expected_coda = <<~'EOS'.chop
      .SH "UI MACROS"
      .sp
      \f(CRCtrl\0+\0s\fP
      EOS
      output = Asciidoctor.convert input, backend: :manpage, attributes: { 'experimental' => '' }
      assert output.end_with? expected_coda
    end

    test 'should format single menu reference in italic' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      == UI Macros

      menu:File[]
      EOS
      expected_coda = <<~'EOS'.chop
      .SH "UI MACROS"
      .sp
      \fIFile\fP
      EOS
      output = Asciidoctor.convert input, backend: :manpage, attributes: { 'experimental' => '' }
      assert output.end_with? expected_coda
    end

    test 'should format menu sequence in italic separated by carets' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      == UI Macros

      menu:File[New Tab]
      EOS
      expected_coda = <<~'EOS'.chop
      .SH "UI MACROS"
      .sp
      \fIFile\0\(fc\0New Tab\fP
      EOS
      output = Asciidoctor.convert input, backend: :manpage, attributes: { 'experimental' => '' }
      assert output.end_with? expected_coda
    end

    test 'should format menu sequence with submenu in italic separated by carets' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      == UI Macros

      menu:View[Zoom > Zoom In]
      EOS
      expected_coda = <<~'EOS'.chop
      .SH "UI MACROS"
      .sp
      \fIView\fP\0\(fc\0\fIZoom\fP\0\(fc\0\fIZoom In\fP
      EOS
      output = Asciidoctor.convert input, backend: :manpage, attributes: { 'experimental' => '' }
      assert output.end_with? expected_coda
    end
  end

  context 'xrefs' do
    test 'should populate automatic link text for internal xref' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      You can access this information using the options listed under <<_generic_program_information>>.

      == Options

      === Generic Program Information

      --help:: Output a usage message and exit.

      -V, --version:: Output the version number of grep and exit.
      EOS
      output = Asciidoctor.convert input, backend: :manpage, attributes: { 'experimental' => '' }
      assert_includes output, 'You can access this information using the options listed under Generic Program Information.'
    end

    test 'should populate automatic link text for each occurrence of internal xref' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      You can access this information using the options listed under <<_generic_program_information>>.

      The options listed in <<_generic_program_information>> should always be used by themselves.

      == Options

      === Generic Program Information

      --help:: Output a usage message and exit.

      -V, --version:: Output the version number of grep and exit.
      EOS
      output = Asciidoctor.convert input, backend: :manpage, attributes: { 'experimental' => '' }
      assert_includes output, 'You can access this information using the options listed under Generic Program Information.'
      assert_includes output, 'The options listed in Generic Program Information should always be used by themselves.'
    end

    test 'should uppercase the reftext for level-2 section titles if the reftext matches the secton title' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      If you read nothing else, read the <<_foo_bar>> section.

      === Options

      --foo-bar _foobar_::
      Puts the foo in your bar.
      See <<_foo_bar>> section for details.

      == Foo Bar

      Foo goes with bar, not baz.
      EOS

      output = Asciidoctor.convert input, backend: :manpage, attributes: { 'experimental' => '' }
      assert_includes output, 'If you read nothing else, read the FOO BAR section.'
      assert_includes output, 'See FOO BAR section for details.'
    end
  end

  context 'Footnotes' do
    test 'should generate list of footnotes using numbered list with numbers enclosed in brackets' do
      [true, false].each do |standalone|
        input = <<~EOS.chop
        #{SAMPLE_MANPAGE_HEADER}

        text.footnote:[first footnote]

        more text.footnote:[second footnote]
        EOS
        expected_coda = <<~'EOS'.chop
        .sp
        text.[1]
        .sp
        more text.[2]
        .SH "NOTES"
        .IP [1]
        first footnote
        .IP [2]
        second footnote
        EOS
        if standalone
          expected_coda = <<~EOS.chop
          #{expected_coda}
          .SH "AUTHOR"
          .sp
          Author Name
          EOS
        end
        output = Asciidoctor.convert input, backend: :manpage, standalone: standalone
        assert output.end_with? expected_coda
      end
    end

    test 'should number footnotes according to footnote index' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      text.footnote:fn1[first footnote]footnote:[second footnote]

      more text.footnote:fn1[]
      EOS
      expected_coda = <<~'EOS'.chop
      .sp
      text.[1][2]
      .sp
      more text.[1]
      .SH "NOTES"
      .IP [1]
      first footnote
      .IP [2]
      second footnote
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert output.end_with? expected_coda
    end

    test 'should format footnote with bare URL' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      text.footnote:[https://example.org]
      EOS
      expected_coda = <<~'EOS'.chop
      .SH "NOTES"
      .IP [1]
      .URL "https://example.org" "" ""
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert output.end_with? expected_coda
    end

    test 'should format footnote with text before bare URL' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      text.footnote:[see https://example.org]
      EOS
      expected_coda = <<~'EOS'.chop
      .SH "NOTES"
      .IP [1]
      see \c
      .URL "https://example.org" "" ""
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert output.end_with? expected_coda
    end

    test 'should format footnote with text after bare URL' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      text.footnote:[https://example.org is the place]
      EOS
      expected_coda = <<~'EOS'.chop
      .SH "NOTES"
      .IP [1]
      .URL "https://example.org" "" ""
      is the place
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert output.end_with? expected_coda
    end

    test 'should format footnote with URL macro' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      text.footnote:[go to https://example.org[example site].]
      EOS
      expected_coda = <<~'EOS'.chop
      .SH "NOTES"
      .IP [1]
      go to \c
      .URL "https://example.org" "example site" "."
      EOS
      output = Asciidoctor.convert input, backend: :manpage
      assert output.end_with? expected_coda
    end

    test 'should produce a warning message and output fallback text at location of macro of unresolved footnote' do
      input = <<~EOS.chop
      #{SAMPLE_MANPAGE_HEADER}

      text.footnote:does-not-exist[]
      EOS
      expected_coda = <<~'EOS'.chop
      .sp
      text.[does\-not\-exist]
      EOS
      using_memory_logger do |logger|
        output = Asciidoctor.convert input, backend: :manpage
        assert output.end_with? expected_coda
        assert_message logger, :WARN, 'invalid footnote reference: does-not-exist'
      end
    end
  end

  context 'Environment' do
    test 'should use SOURCE_DATE_EPOCH as modified time of input file and local time' do
      old_source_date_epoch = ENV.delete 'SOURCE_DATE_EPOCH'
      begin
        ENV['SOURCE_DATE_EPOCH'] = '1234123412'
        output = Asciidoctor.convert SAMPLE_MANPAGE_HEADER, backend: :manpage, standalone: true
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
        Asciidoctor.convert SAMPLE_MANPAGE_HEADER, backend: :manpage, standalone: true
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
