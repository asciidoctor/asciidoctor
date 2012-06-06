require 'cgi'
require 'erb'

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
#   doc  = Asciidoc::Document.new(lines)
#   html = doc.render(template_path)
module Asciidoc
  REGEXP = {
    # [[Foo]]  (also allows, say, [[[]] or [[[Foo[f]], but I don't think it is supposed to (TODO))
    :anchor   => /^\[(\[.+\])\]\s*$/,

    # [[[Foo]]]  (does not suffer quite the same malady as :anchor, but almost. Allows [ but not ] in internal capture
    :biblio   => /\[\[\[([^\]]+)\]\]\]/,

    # [caption="Foo"]
    :caption  => /^\[caption=\"([^\"]+)\"\]/,

    # <1> Foo
    :colist   => /^(\<\d+\>)\s*(.*)/,

    # // (and then whatever)
    :comment  => /^\/\/\s/,

    # +   (note that Asciidoc appears to allow continuations using + at the end of the previous line and indenting
    #      the following line (as in :lit_par))
    :continue => /^\+\s*$/,

    # foo::  ||  foo;;
    :dlist    => /^(\s*)(\S.*)(::|;;)\s*$/,

    # ====
    :example  => /^={4,}\s*$/,

    # ======  || ------ || ~~~~~~ || ^^^^^^ || ++++++
    :line     => /^([=\-~^\+])+\s*$/,

    # ----
    :listing  => /^\-{4,}\s*$/,

    # ....
    :lit_blk  => /^\.{4,}\s*$/,

    # <TAB>Foo  or one-or-more-spaces-or-tabs then whatever
    :lit_par  => /^([ \t]+.*)$/,

    # "Wooble"  ||  Wooble
    :name     => /^(["A-Za-z].*)\s*$/,  # I believe this fails to require " chars to be paired (TODO)

    # [NOTE]
    :note     => /^\[NOTE\]\s*$/,

    # --
    :oblock   => /^\-\-\s*$/,

    # 1.Foo  ||  1. Foo  ||  . Foo
    :olist    => /^\s*(\d+\.|\. )(.*)$/,

    # ____
    :quote    => /^_{4,}\s*$/,

    # .Foo   but not  . Foo or ..Foo
    :title    => /^\.([^\s\.].*)\s*$/,

    # * Foo  ||  - Foo
    :ulist    => /^\s*([\*\-])\s+(.*)$/,

    # [verse]
    :verse    => /^\[verse\]\s*$/
  }
  /(^|[^\\])\{(\w[\w\-]+\w)\}/

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

  require 'asciidoc/block'
  require 'asciidoc/document'
  require 'asciidoc/list_item'
  require 'asciidoc/renderer'
  require 'asciidoc/section'
end
