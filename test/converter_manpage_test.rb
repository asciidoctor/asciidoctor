# encoding: UTF-8
unless defined? ASCIIDOCTOR_PROJECT_DIR
  $: << File.dirname(__FILE__); $:.uniq!
  require 'test_helper'
end
require 'asciidoctor'
require 'asciidoctor/converter/manpage'

context 'Converter' do
  context 'ManPageConverter' do

    test 'should generate multiple authors in header' do
      input = <<-EOS
= asciidoctor(1)
Dan Allen; Sarah White; Ryan Waldron
      EOS

      output = render_string input, :converter => Asciidoctor::Converter::ManPageConverter
      assert_match(/.\\"    Author: Dan Allen, Sarah White, Ryan Waldron/, output)
    end

    test 'should populate NAME section if present and put it after header without spaces' do
      input = <<-EOS
= asciidoctor(1)
Dan Allen; Sarah White; Ryan Waldron
:doctype: manpage
:man manual: Asciidoctor Manual
:man source: Asciidoctor 1.5.2
:page-layout: base

== NAME

asciidoctor - converts AsciiDoc source files to HTML, DocBook and other formats

== SYNOPSIS

*asciidoctor* [_OPTION_]... _FILE_...

      EOS

      output = render_string input, :converter => Asciidoctor::Converter::ManPageConverter
      assert_match(/\.ad l\n.SH "NAME"\n.sp\nasciidoctor \\- converts AsciiDoc source files to HTML, DocBook and other formats/,
                   output)
      refute_match(/.SH "NAME"\n.sp\nasciidoctor \\-.?\n/,
                   output)
    end

    test 'should not put an empty NAME section' do
      input = <<-EOS
= asciidoctor(1)
Dan Allen; Sarah White; Ryan Waldron
:doctype: manpage
:man manual: Asciidoctor Manual
:man source: Asciidoctor 1.5.2
:page-layout: base

== SYNOPSIS

*asciidoctor* [_OPTION_]... _FILE_...

      EOS

      output = render_string input, :converter => Asciidoctor::Converter::ManPageConverter
      refute_match(/.SH "NAME"\n.sp\nasciidoctor \\-.?\n/,
                   output)
    end

    # NOTE This is properly rendered by man, no reason to disallow it
    test 'should put preamble before the NAME section' do
      input = <<-EOS
= asciidoctor(1)
Dan Allen; Sarah White; Ryan Waldron
:doctype: manpage
:man manual: Asciidoctor Manual
:man source: Asciidoctor 1.5.2
:page-layout: base

my preamble is to be used under PREAMBLE

== NAME

asciidoctor - converts AsciiDoc source files to HTML, DocBook and other formats

== SYNOPSIS

*asciidoctor* [_OPTION_]... _FILE_...

      EOS

      output = render_string input, :converter => ::Asciidoctor::Converter::ManPageConverter
      assert_match(/.SH "NAME"\n.sp\nasciidoctor \\- converts AsciiDoc source files to HTML, DocBook and other formats/,
                   output)
      assert_match(/\.ad l\nmy preamble is to be used under PREAMBLE\n\.sp\n/,
                   output)
      refute_match(/.SH "NAME"\nasciidoctor \\-.?\n/,
                   output)
    end
  end
end
