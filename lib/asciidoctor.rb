require 'rubygems'
require 'cgi'
require 'erb'

$:.unshift(File.dirname(__FILE__))
$:.unshift(File.join(File.dirname(__FILE__), '..', 'vendor'))

# Public: Methods for parsing Asciidoc input files and rendering documents
# using erb templates.
#
# Asciidoc documents comprise a header followed by zero or more sections.
# Sections are composed of blocks of content.  For example:
#
#   Doc Title
#   =========
#
#   SECTION 1
#   ---------
#
#   This is a paragraph block in the first section.
#
#   SECTION 2
#
#   This section has a paragraph block and an olist block.
#
#   1. Item 1
#   2. Item 2
#
# Examples:
#
#   lines = File.readlines(filename)
#
#   doc  = Asciidoctor::Document.new(lines)
#   html = doc.render(template_path)
module Asciidoctor
  REGEXP = {
    # [[Foo]]  (also allows, say, [[[]] or [[[Foo[f]], but I don't think it is supposed to (TODO))
    :anchor           => /^\[(\[.+\])\]\s*$/,

    # Foowhatevs [[Bar]]
    :anchor_embedded  => /^(.*)\[\[([^\]]+)\]\]\s*$/,

    # +   Attribute values treat lines ending with ' +' as a continuation,
    #     not a line-break as elsewhere in the document, where this is
    #     a forced line break. This should be the same regexp as :line_break,
    #     below, but it gets its own entry because readability ftw, even
    #     though repeating regexps ftl.
    :attr_continue    => /(.*)(?:^|\s)\+$/,

    # [[[Foo]]]  (does not suffer quite the same malady as :anchor, but almost. Allows [ but not ] in internal capture
    :biblio           => /\[\[\[([^\]]+)\]\]\]/,

    # [caption="Foo"]
    :caption          => /^\[caption=\"([^\"]+)\"\]/,

    # <1> Foo
    :colist           => /^(\<\d+\>)\s*(.*)/,

    # // (and then whatever)
    :comment          => /^\/\/\s/,

    # foo::  ||  foo;;
    # Should be followed by a definition line, e.g.,
    # foo::
    #    That which precedes 'bar' (see also, bar)
    :dlist            => /^(\s*)(\S.*)(::|;;)\s*$/,

    # ====
    :example          => /^={4,}\s*$/,

    # == Foo
    # Yields a Level 2 title, so exactly the same as
    #   Foo
    #   ~~~
    # would yield.  match[1] is the == sequence, whose
    # length determines the level, and match[2] is the
    # title itself.
    :level_title      => /^(={2,5})\s+(\S.*)\s*$/,

    # ======  || ------ || ~~~~~~ || ^^^^^^ || ++++++
    :line             => /^([=\-~^\+])+\s*$/,

    # +   From the Asciidoc User Guide: "A plus character preceded by at
    #     least one space character at the end of a non-blank line forces
    #     a line break. It generates a line break (br) tag for HTML outputs.
    #
    #     This is the correct regexp to match what the User Guide actually
    #     says to do:
    #     :line_break        => /^(.*(?:\S+)+.*)\s\+$/,
    #
    # But the regexp we're using (below), is what asciidoc *actually*
    # does for HTML output, courtesy of the default html4.conf file (under
    # the [replacements2] section).
    #
    # +      (would not match because there's no space before +)
    #  +     (would match and capture '')
    # Foo +  (would and capture 'Foo')
    :line_break       => /^(.*)\s\+$/,

    # ----
    :listing          => /^\-{4,}\s*$/,

    # [source, ruby]
    # Treats the next paragraph as a :listing block
    :listing_source   => /^\[source,\s*([^\]]+)\]\s*$/,

    # ....
    :lit_blk          => /^\.{4,}\s*$/,

    # <TAB>Foo  or one-or-more-spaces-or-tabs then whatever
    :lit_par          => /^([ \t]+.*)$/,

    # "Wooble"  ||  Wooble
    :name             => /^(["A-Za-z].*)\s*$/,  # I believe this fails to require " chars to be paired (TODO)

    # [NOTE]
    :note             => /^\[NOTE\]\s*$/,

    # --
    :oblock           => /^\-\-\s*$/,

    # 1.Foo  ||  1. Foo  ||  . Foo
    :olist            => /^\s*(\d+\.|\. )(.*)$/,

    # ____
    :quote            => /^_{4,}\s*$/,

    # ''''
    :ruler            => /^'{3,}\s*$/,

    # ****
    :sidebar_blk      => /^\*{4,}\s*$/,

    #     and blah blah blah
    # ^^^^  <--- whitespace
    :starts_with_whitespace => /\s+(.+)\s+\+\s*$/,

    # .Foo   but not  . Foo or ..Foo
    :title            => /^\.([^\s\.].*)\s*$/,

    # * Foo  ||  - Foo
    :ulist            => /^ \s* (- | \*{1,5}) \s+ (.*) $/x,

    # [verse]
    :verse            => /^\[verse\]\s*$/
  }

  INTRINSICS = Hash.new{|h,k| STDERR.puts "Missing intrinsic: #{k.inspect}"; "{#{k}}"}.merge(
    'startsb'    => '[',
    'endsb'      => ']',
    'caret'      => '^',
    'asterisk'   => '*',
    'tilde'      => '~',
    'litdd'      => '--',
    'plus'       => '+',
    'apostrophe' => "'",
    'backslash'  => "\\",
    'backtick'   => '`'
  )

  HTML_ELEMENTS = {
    'br-asciidoctor' => '<br/>'
  }

  require 'asciidoctor/block'
  require 'asciidoctor/debug'
  require 'asciidoctor/document'
  require 'asciidoctor/errors'
  require 'asciidoctor/list_item'
  require 'asciidoctor/render_templates'
  require 'asciidoctor/renderer'
  require 'asciidoctor/section'
  require 'asciidoctor/string'
  require 'asciidoctor/version'
end
