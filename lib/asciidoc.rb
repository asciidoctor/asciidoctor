require 'cgi'
require 'erb'
require 'tilt'

# Public: Methods for parsing Asciidoc input files and rendering documents
# using Tilt-compatible templates.
#
# Asciidoc documents are comprised of a header followed by zero or more
# sections, and sections are comprised of blocks of content.  For example:
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
#   doc  = Asciidoc.new(lines)
#   html = doc.render(template_path)
module Asciidoc
  REGEXP = {
    :name     => /^(["A-Za-z].*)\s*$/,
    :line     => /^([=\-~^\+])+\s*$/,
    :verse    => /^\[verse\]\s*$/,
    :note     => /^\[NOTE\]\s*$/,
    :dlist    => /^(\s*)(\S.*)(::|;;)\s*$/,
    :olist    => /^\s*(\d+\.|\. )(.*)$/,
    :ulist    => /^\s*([\*\-])\s+(.*)$/,
    :title    => /^\.([^\s\.].*)\s*$/,
    :quote    => /^_{4,}\s*$/,
    :colist   => /^(\<\d+\>)\s*(.*)/,
    :oblock   => /^\-\-\s*$/,
    :anchor   => /^\[(\[.+\])\]\s*$/,
    :biblio   => /\[\[\[([^\]]+)\]\]\]/,
    :comment  => /^\/\/\s/,
    :listing  => /^\-{4,}\s*$/,
    :example  => /^={4,}\s*$/,
    :lit_blk  => /^\.{4,}\s*$/,
    :lit_par  => /^([ \t]+.*)$/,
    :caption  => /^\[caption=\"([^\"]+)\"\]/,
    :continue => /^\+\s*$/
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

  # Public: Methods for rendering Asciidoc Documents, Sections, and Blocks
  # using Tile-compatible templates.
  class Renderer
    # Public: Initialize an Asciidoc::Renderer object.
    #
    # template_dir - the String pathname of the directory containing template
    #                files that should be used for subsequent render requests.
    def initialize(template_dir, options={})
      @debug = !!options[:debug]

      files = Dir.glob(File.join(template_dir, '*')).select{|f| File.stat(f).file?}
      @views = files.inject({}) do |view_hash, view|
        name = File.basename(view).split('.').first
        view_hash.merge!(name => Tilt.new(view, nil, :trim => '<>'))
      end

      @render_stack = []
    end

    # Public: Render an Asciidoc object with a specified view template.
    #
    # view   - the String view template name.
    # object - the Object to be passed to Tilt as an evaluation scope.
    # locals - the optional Hash of locals to be passed to Tile (default {})
    def render(view, object, locals={})
      @render_stack.push([view, object])
      ret = @views[view].render(object, locals)

      if @debug
        prefix = ''
        STDERR.puts '=' * 80
        STDERR.puts "Rendering:"
        @render_stack.each do |stack_view, stack_obj|
          obj_info = case stack_obj
                     when Section; "SECTION #{stack_obj.name}"
                     when Block;
                       if stack_obj.context == :dlist
                         dt_list = stack_obj.buffer.map{|dt,dd| dt.content.strip}.join(', ')
                         "BLOCK :dlist (#{dt_list})"
                       else
                         "BLOCK #{stack_obj.context.inspect}"
                       end
                     else stack_obj.class
                     end
          STDERR.puts "#{prefix}#{stack_view}: #{obj_info}"
          prefix << '  '
        end
        STDERR.puts '-' * 80
        STDERR.puts ret.inspect
        STDERR.puts '=' * 80
        STDERR.puts
      end

      @render_stack.pop
      ret
    end
  end

  # Public: Methods for managing items for Asciidoc olists, ulist, and dlists.
  class ListItem
    # Public: Get the Array of Blocks from the list item's continuation.
    attr_reader :blocks

    # Public: Get/Set the String content.
    attr_accessor :content

    # Public: Get/Set the String list item anchor name.
    attr_accessor :anchor

    # Public: Initialize an Asciidoc::ListItem object.
    #
    # content - the String content (default '')
    def initialize(content='')
      @content = content
      @blocks  = []
    end
  end

  # Public: Methods for managing blocks of Asciidoc content in a section.
  #
  # Examples
  #
  #   block = Asciidoc::Block.new(:paragraph, ["`This` is a <test>"])
  #   block.content
  #   => ["<em>This</em> is a &lt;test&gt;"]
  class Block
    # Public: Get the Symbol context for this section block.
    attr_reader :context

    # Public: Get the Array of sub-blocks for this section block.
    attr_reader :blocks

    # Public: Get/Set the original Array content for this section block.
    attr_accessor :buffer

    # Public: Get/Set the String section anchor name.
    attr_accessor :anchor

    # Public: Get/Set the String block title.
    attr_accessor :title

    # Public: Get/Set the String block caption.
    attr_accessor :caption

    # Public: Initialize an Asciidoc::Block object.
    #
    # parent  - The parent Asciidoc Object.
    # context - The Symbol context name for the type of content.
    # buffer  - The Array buffer of source data.
    def initialize(parent, context, buffer=nil)
      @parent = parent
      @context = context
      @buffer = buffer

      @blocks = []
    end

    # Public: Get the Asciidoc::Document instance to which this Block belongs
    def document
      @parent.is_a?(Document) ? @parent : @parent.document
    end

    # Public: Get the Asciidoc::Renderer instance being used for the ancestor
    # Asciidoc::Document instance.
    def renderer
      @parent.renderer
    end

    # Public: Get the rendered String content for this Block.  If the block
    # has child blocks, the content method should cause them to be
    # rendered and returned as content that can be included in the
    # parent block's template.
    def render
      renderer.render("section_#{context}", self)
    end

    # Public: Get an HTML-ified version of the source buffer, with special
    # Asciidoc characters and entities converted to their HTML equivalents.
    #
    # Examples
    #
    #   block = Block.new(:paragraph, ['`This` is what happens when you <meet> a stranger in the <alps>!']
    #   block.content
    #   => ["<em>This</em> is what happens when you &lt;meet&gt; a stranger in the &lt;alps&gt;!"]
    #
    # TODO:
    # * forced line breaks
    # * bold, mono
    # * double/single quotes
    # * super/sub script
    def content
      case @context
      when :dlist
        @buffer.map do |dt, dd|
          if !dt.anchor.nil? && !dt.anchor.empty?
            html_dt = "<a id=#{dt.anchor}></a>" + htmlify(dt.content)
          else
            html_dt = htmlify(dt.content)
          end
          if dd.content.empty?
            html_dd = ''
          else
            html_dd = "<p>#{htmlify(dd.content)}</p>"
          end
          html_dd += dd.blocks.map{|block| block.render}.join

          [html_dt, html_dd]
        end
      when :oblock, :quote
        blocks.map{|block| block.render}.join
      when :olist, :ulist, :colist
        @buffer.map do |li|
          htmlify(li.content) + li.blocks.map{|block| block.render}.join
        end
      when :listing
        @buffer.map{|l| CGI.escapeHTML(l).gsub(/(<\d+>)/,'<b>\1</b>')}.join
      when :literal
        htmlify( @buffer.join.gsub( '*', '{asterisk}' ).gsub( '\'', '{apostrophe}' ))
      when :verse
        htmlify( @buffer.map{ |l| l.strip }.join( "\n" ) )
      else
        htmlify( @buffer.map{ |l| l.lstrip }.join )
      end
    end

      private

        # Private: Return a String HTML version of the source string, with
        # Asciidoc characters converted and HTML entities escaped.
        #
        # string - The String source string in Asciidoc format.
        #
        # Examples
        #
        #   asciidoc_string = "Make 'this' <emphasized>"
        #   htmlify(asciidoc_string)
        #   => "Make <em>this</em> &lt;emphasized&gt;"
        def htmlify(string)
          unless string.nil?
            html = string.dup

            # Convert reference links to "link:" asciidoc for later HTMLification.
            # This ensures that eg. "<<some reference>>" is turned into a link but
            # "`<<<<<` and `>>>>>` are conflict markers" is not.  This is much
            # easier before the HTML is escaped and <> are turned into entities.
            html.gsub!( /(^|[^<])<<([^<>,]+)(,([^>]*))?>>/ ) { "#{$1}link:##{$2}[" + ($4.nil?? document.references[$2] : $4).to_s + "]" }

            # Do the same with URLs
            html.gsub!( /(^|[^`])(https?:\/\/[^\[ ]+)(\[+[^\]]*\]+)?/ ) do
              pre=$1
              url=$2
              link=( $3 || $2 ).gsub( /(^\[|\]$)/,'' )
              link = url if link.empty?

              "#{pre}link:#{url}[#{link}]"
            end

            CGI.escapeHTML(html).
              gsub(REGEXP[:biblio], '<a name="\1">[\1]</a>').
              gsub(/`([^`]+)`/m) { "<tt>#{$1.gsub( '*', '{asterisk}' ).gsub( '\'', '{apostrophe}' )}</tt>" }.
              gsub(/``(.*?)''/m, '&#147;\1&#148;').
              gsub(/(^|\W)'([^']+)'/m, '\1<em>\2</em>').
              gsub(/(^|\W)_([^_]+)_/m, '\1<em>\2</em>').
              gsub(/\*([^\*]+)\*/m, '<strong>\1</strong>').
              gsub(/(?<!\\)\{(\w[\w\-]+\w)\}/) { INTRINSICS[$1] }.
              gsub(/\\([\{\}\-])/, '\1').
              gsub(/linkgit:([^\]]+)\[(\d+)\]/, '<a href="\1.html">\1(\2)</a>').
              gsub(/link:([^\[]+)(\[+[^\]]*\]+)/ ) { "<a href=\"#{$1}\">#{$2.gsub( /(^\[|\]$)/,'' )}</a>" }
          end
        end
  end

  # Public: Methods for managing sections of Asciidoc content in a document.
  # The section responds as an Array of content blocks by delegating
  # block-related methods to its @blocks Array.
  #
  # Examples
  #
  #   section = Asciidoc::Section.new
  #   section.name = 'DESCRIPTION'
  #   section.anchor = 'DESCRIPTION'
  #
  #   section.size
  #   => 0
  #
  #   section.section_id
  #   => "_description"
  #
  #   section << new_block
  #   section.size
  #   => 1
  class Section
    # Public: Get/Set the Integer section level.
    attr_accessor :level

    # Public: Set the String section name.
    attr_writer :name

    # Public: Get/Set the String section title.
    attr_accessor :title

    # Public: Get/Set the String section caption.
    attr_accessor :caption

    # Public: Get/Set the String section anchor name.
    attr_accessor :anchor

    # Public: Get the Array of section blocks.
    attr_reader :blocks

    # Public: Initialize an Asciidoc::Section object.
    #
    # parent - The parent Asciidoc Object.
    def initialize(parent)
      @parent = parent
      @blocks = []
    end

    # Public: Get the String section name with intrinsics converted
    #
    # Examples
    #
    #   section.name = "git-web{litdd}browse(1) Manual Page"
    #   section.name
    #   => "git-web--browse(1) Manual Page"
    #
    # Returns the String section name
    def name
      @name && @name.gsub(/(^|[^\\])\{(\w[\w\-]+\w)\}/) { $1 + INTRINSICS[$2] }.gsub( /`([^`]+)`/, '<tt>\1</tt>' )
    end

    # Public: Get the String section id
    #
    # Examples
    #
    #   section = Section.new
    #   section.name = "Foo"
    #   section.section_id
    #   => "_foo"
    def section_id
      "_#{name && name.downcase.gsub(' ','_')}"
    end

    # Public: Get the Asciidoc::Document instance to which this Block belongs
    def document
      @parent.is_a?(Document) ? @parent : @parent.document
    end

    # Public: Get the Asciidoc::Renderer instance being used for the ancestor
    # Asciidoc::Document instance.
    def renderer
      @parent.renderer
    end

    # Public: Get the rendered String content for this Section and all its child
    # Blocks.
    def render
      renderer.render('section', self)
    end

    # Public: Get the String section content by aggregating rendered section blocks.
    #
    # Examples
    #
    #   section = Section.new
    #   section << 'foo'
    #   section << 'bar'
    #   section << 'baz'
    #   section.content
    #   "<div class=\"paragraph\"><p>foo</p></div>\n<div class=\"paragraph\"><p>bar</p></div>\n<div class=\"paragraph\"><p>baz</p></div>"
    def content
      @blocks.map{|block| block.render}.join
    end

    # Public: Get the Integer number of blocks in the section.
    #
    # Examples
    #
    #   section = Section.new
    #
    #   section.size
    #   => 0
    #
    #   section << 'foo'
    #   section << 'bar'
    #   section.size
    #   => 2
    def size
      @blocks.size
    end

    # Public: Get the element at i in the array of section blocks.
    #
    # i - The Integer array index number.
    #
    #   section = Section.new
    #
    #   section << 'foo'
    #   section << 'bar'
    #   section[1]
    #   => "bar"
    def [](i)
      @blocks[i]
    end

    # Public: Delete the element at i in the array of section blocks,
    # returning that element or nil if i is out of range.
    #
    # i - The Integer array index number.
    #
    #   section = Section.new
    #
    #   section << 'foo'
    #   section << 'bar'
    #   section.delete_at(1)
    #   => "bar"
    #
    #   section.blocks
    #   => ["foo"]
    def delete_at(i)
      @blocks.delete_at(i)
    end

    # Public: Append a content block to this section's list of blocks.
    #
    # block - The new section block.
    #
    #   section = Section.new
    #
    #   section << 'foo'
    #   section << 'bar'
    #   section.blocks
    #   => ["foo", "bar"]
    def <<(block)
      @blocks << block
    end

    # Public: Insert a content block at the specified index in this section's
    # list of blocks.
    #
    # i - The Integer array index number.
    # val = The content block to insert.
    #
    #   section = Section.new
    #
    #   section << 'foo'
    #   section << 'baz'
    #   section.insert(1, 'bar')
    #   section.blocks
    #   ["foo", "bar", "baz"]
    def insert(i, block)
      @blocks.insert(i, block)
    end

    # Public: Get the Integer index number of the first content block element
    # for which the provided block returns true.  Returns nil if no match is
    # found.
    #
    # block - A block that can be used to determine whether a supplied element
    #         is a match.
    #
    #   section = Section.new
    #
    #   section << 'foo'
    #   section << 'bar'
    #   section << 'baz'
    #   section.index{|el| el =~ /^ba/}
    #   => 1
    def index(&block)
      @blocks.index(&block)
    end
  end

  # Public: Methods for parsing Asciidoc documents and rendering them
  # using Tilt-compatible templates.
  class Document

    # Public: Get the String document source.
    attr_reader :source

    # Public: Get the Asciidoc::Renderer instance currently being used
    # to render this Document.
    attr_reader :renderer

    # Public: Get the Hash of document references
    attr_reader :references

    # Public: Initialize an Asciidoc object.
    #
    # data  - The String Asciidoc source document.
    # block - A block that can be used to retrieve external Asciidoc
    #         data to include in this document.
    #
    # Examples
    #
    #   base = File.dirname(filename)
    #   data = File.readlines(filename)
    #   doc  = Asciidoc.new(data) do |inc|
    #     incfile = File.join(base, inc)
    #     File.read(incfile)
    #   end
    def initialize(name, data, &block)
      raw_source = data.dup
      @defines = {}
      @references = {}

      include_regexp = /^include::([^\[]+)\[\]\s*\n/
      while inc = raw_source.match(include_regexp)
        raw_source.sub!(include_regexp){|st| yield inc[1]}
      end

      ifdef_regexp = /^(ifdef|ifndef)::([^\[]+)\[\]/
      endif_regexp = /^endif::/
      defattr_regexp = /^:([^:]+):\s*(.*)\s*$/
      conditional_regexp = /^\s*\{([^\?]+)\?\s*([^\}]+)\s*\}/
      skip_to = nil
      @lines = raw_source.each_line.inject([]) do |lines, line|
        if !skip_to.nil?
          skip_to = nil if line.match(skip_to)
        elsif match = line.match(ifdef_regexp)
          attr = match[2]
          skip = case match[1]
                 when 'ifdef';  !@defines.has_key?(attr)
                 when 'ifndef'; @defines.has_key?(attr)
                 end
          skip_to = /^endif::#{attr}\[\]\s*\n/ if skip
        elsif match = line.match(defattr_regexp)
          @defines[match[1]] = match[2]
        elsif !line.match(endif_regexp)
          while match = line.match(conditional_regexp)
            value = @defines.has_key?(match[1]) ? match[2] : ''
            line.sub!(conditional_regexp, value)
          end
          lines << line unless line.match(REGEXP[:comment])
        end

        lines
      end

      # Process bibliography references, so they're available when text
      # before the reference is being rendered.
      @lines.each do |line|
        if biblio = line.match(REGEXP[:biblio])
          references[biblio[1]] = "[#{biblio[1]}]"
        end
      end

      @source = @lines.join

      @root = next_section(@lines)
      if @root.blocks.first.is_a?(Section)
        @header = @root.blocks.shift
      else
        @preamble = Section.new(self)
        while @root.blocks.first.is_a?(Block)
          @preamble << @root.blocks.shift
        end
      end
    end

    # Public: Render the Asciidoc document using Tilt-compatible templates in
    # the specified path.
    #
    # template_base - The String pathname of the directory containing templates.
    #
    # Examples
    #
    #   Dir.entries(template_dir)
    #   => ['.', '..', 'document.html.erb', 'section.html.erb', 'section_paragraph.html.erb', ...]
    #
    #   doc.render(template_dir)
    #   => "<h1>Doc Title</h1>\n<div class=\"section\">\n  <div class=\"paragraph\"><p>Foo</p></div>\n</div>\n"
    def render(template_dir)
      @renderer = Renderer.new(template_dir)
      html = @renderer.render('document', @root, :header => @header, :preamble => @preamble)
      @renderer = nil

      html
    end

    private

      # Private: Strip off leading blank lines in the Array of lines.
      #
      # lines - the Array of String lines.
      #
      # Returns nil.
      #
      # Examples
      #
      #   content
      #   => ["\n", "\t\n", "Foo\n", "Bar\n", "\n"]
      #
      #   skip_blank(content)
      #   => nil
      #
      #   lines
      #   => ["Foo\n", "Bar\n"]
      def skip_blank(lines)
        while lines.any? && lines.first.strip.empty?
          lines.shift
        end

        nil
      end

      # Private: Strip off and return the list item segment (one or more contiguous blocks) from the Array of lines.
      #
      # lines   - the Array of String lines.
      # options - an optional Hash of processing options:
      #           * :alt_ending may be used to specify a regular expression match other than
      #             a blank line to signify the end of the segment.
      # Returns the Array of lines from the next segment.
      #
      # Examples
      #
      #   content
      #   => ["First paragraph\n", "+\n", "Second paragraph\n", "--\n", "Open block\n", "\n", "Can have blank lines\n", "--\n", "\n", "In a different segment\n"]
      #
      #   list_item_segment(content)
      #   => ["First paragraph\n", "+\n", "Second paragraph\n", "--\n", "Open block\n", "\n", "Can have blank lines\n", "--\n"]
      #
      #   content
      #   => ["In a different segment\n"]
      def list_item_segment(lines, options={})
        alternate_ending = options[:alt_ending]
        segment = []

        skip_blank(lines)

        # Grab lines until the first blank line not inside an open block
        in_oblock = false
        in_listing = false
        while lines.any?
          this_line = lines.shift
          in_oblock = !in_oblock if this_line.match(REGEXP[:oblock])
          in_listing = !in_listing if this_line.match(REGEXP[:listing])
          if !in_oblock && !in_listing
            if this_line.strip.empty?
              # From the Asciidoc user's guide:
              #   Another list or a literal paragraph immediately following a list item will be implicitly included in the list item
              next_nonblank = lines.detect{|l| !l.strip.empty?}
              if !next_nonblank.nil? &&
                 ( alternate_ending.nil? ||
                   !next_nonblank.match(alternate_ending)
                 ) &&
                 ( next_nonblank.match(REGEXP[:ulist])  ||
                   next_nonblank.match(REGEXP[:olist])  ||
                   next_nonblank.match(REGEXP[:colist]) ||
                   next_nonblank.match(REGEXP[:dlist])  ||
                   next_nonblank.match(REGEXP[:lit_par]) ||
                   next_nonblank.match(REGEXP[:continue])
                 )

                 # Pull blank lines into the segment, so the next thing up for processing
                 # will be the next nonblank line.
                 while lines.first.strip.empty?
                   segment << this_line
                   this_line = lines.shift
                 end
              else
                break
              end
            elsif !alternate_ending.nil? && this_line.match(alternate_ending)
              lines.unshift this_line
              break
            end
          end

          segment << this_line
        end

        segment
      end

      # Private: Return the next block from the section.
      #
      # * Skip over blank lines to find the start of the next content block.
      # * Use defined regular expressions to determine the type of content block.
      # * Based on the type of content block, grab lines to the end of the block.
      # * Return a new Asciidoc::Block or Asciidoc::Section instance with the
      #   content set to the grabbed lines.
      def next_block(lines, parent=self)
        # Skip ahead to the block content
        while lines.any? && lines.first.strip.empty?
          lines.shift
        end

        return nil if lines.empty?

        if match = lines.first.match(REGEXP[:anchor])
          anchor = match[1].match(/^\[(.*)\]/) ? $1 : match[1]
          @references[anchor] = match[1]
          lines.shift
        else
          anchor = nil
        end

        block = nil
        title = nil
        caption = nil
        buffer = []
        while lines.any? && block.nil?
          buffer.clear
          this_line = lines.shift
          next_line = lines.first || ''

          if this_line.match(REGEXP[:comment])
            next
          elsif match = this_line.match(REGEXP[:title])
            title = match[1]
          elsif match = this_line.match(REGEXP[:caption])
            caption = match[1]
          elsif this_line.match(REGEXP[:name]) && next_line.match(REGEXP[:line]) && (this_line.size - next_line.size).abs <= 1
            lines.unshift(this_line)
            lines.unshift(anchor) unless anchor.nil?
            block = next_section(lines)
          elsif this_line.match(REGEXP[:oblock])
            # oblock is surrounded by '--' lines and has zero or more blocks inside
            this_line = lines.shift
            while !this_line.nil? && !this_line.match(REGEXP[:oblock])
              buffer << this_line
              this_line = lines.shift
            end

            while buffer.any? && buffer.last.strip.empty?
              buffer.pop
            end

            block = Block.new(parent, :oblock, [])
            while buffer.any?
              block.blocks << next_block(buffer, block)
            end
          elsif list = [:olist, :ulist, :colist].detect{|l| this_line.match( REGEXP[l] )}
            items = []
            block = Block.new(parent, list)
            while !this_line.nil? && match = this_line.match(REGEXP[list])
              item = ListItem.new

              lines.unshift match[2].lstrip.sub(/^\./, '\.')
              item_segment = list_item_segment(lines, :alt_ending => REGEXP[list])
              while item_segment.any?
                item.blocks << next_block(item_segment, block)
              end

              if item.blocks.any? && item.blocks.first.is_a?(Block) && (item.blocks.first.context == :paragraph || item.blocks.first.context == :literal)
                item.content = item.blocks.shift.buffer.map{|l| l.strip}.join("\n")
              end

              items << item

              skip_blank(lines)

              this_line = lines.shift
            end
            lines.unshift(this_line) unless this_line.nil?

            block.buffer = items
          elsif match = this_line.match(REGEXP[:dlist])
            pairs = []
            block = Block.new(parent, :dlist)

            this_dlist = Regexp.new(/^#{match[1]}(.*)#{match[3]}\s*$/)

            while !this_line.nil? && match = this_line.match(this_dlist)
              if anchor = match[1].match( /\[\[([^\]]+)\]\]/ )
                dt = ListItem.new( $` + $' )
                dt.anchor = anchor[1]
              else
                dt = ListItem.new( match[1] )
              end
              dd = ListItem.new
              lines.shift if lines.any? && lines.first.strip.empty? # workaround eg. git-config OPTIONS --get-colorbool

              dd_segment = list_item_segment(lines, :alt_ending => this_dlist)
              while dd_segment.any?
                dd.blocks << next_block(dd_segment, block)
              end

              if dd.blocks.any? && dd.blocks.first.is_a?(Block) && (dd.blocks.first.context == :paragraph || dd.blocks.first.context == :literal)
                dd.content = dd.blocks.shift.buffer.map{|l| l.strip}.join("\n")
              end

              pairs << [dt, dd]

              skip_blank(lines)

              this_line = lines.shift
            end
            lines.unshift(this_line) unless this_line.nil?
            block.buffer = pairs
          elsif this_line.match(REGEXP[:verse])
            # verse is preceded by [verse] and lasts until a blank line
            this_line = lines.shift
            while !this_line.nil? && !this_line.strip.empty?
              buffer << this_line
              this_line = lines.shift
            end

            block = Block.new(parent, :verse, buffer)
          elsif this_line.match(REGEXP[:note])
            # note is an admonition preceded by [NOTE] and lasts until a blank line
            this_line = lines.shift
            while !this_line.nil? && !this_line.strip.empty? && !this_line.match( REGEXP[:continue] )
              buffer << this_line
              this_line = lines.shift
            end

            block = Block.new(parent, :note, buffer)
          elsif text = [:listing, :example].detect{|t| this_line.match( REGEXP[t] )}
            this_line = lines.shift
            while !this_line.nil? && !this_line.match( REGEXP[text] )
              buffer << this_line
              this_line = lines.shift
            end

            block = Block.new(parent, text, buffer)
          elsif this_line.match( REGEXP[:quote] )
            block = Block.new(parent, :quote)

            this_line = lines.shift
            while !this_line.nil? && !this_line.match( REGEXP[:quote] )
              buffer << this_line
              this_line = lines.shift
            end

            while buffer.any?
              block.blocks << next_block(buffer, block)
            end
          elsif this_line.match(REGEXP[:lit_blk])
            # example is surrounded by '....' (4 or more '.' chars) lines
            this_line = lines.shift
            while !this_line.nil? && !this_line.match(REGEXP[:lit_blk])
              buffer << this_line
              this_line = lines.shift
            end

            block = Block.new(parent, :literal, buffer)
          elsif this_line.match(REGEXP[:lit_par])
            # literal paragraph is contiguous lines starting with
            # one or more space or tab characters
            while !this_line.nil? && this_line.match(REGEXP[:lit_par])
              buffer << this_line
              this_line = lines.shift
            end
            lines.unshift( this_line ) unless this_line.nil?

            block = Block.new(parent, :literal, buffer)
          else
            # paragraph is contiguous nonblank/noncontinuation lines
            while !this_line.nil? && !this_line.strip.empty?
              break if this_line.match(REGEXP[:continue])
              if this_line.match( REGEXP[:listing] ) || this_line.match( REGEXP[:oblock] )
                lines.unshift this_line
                break
              end
              buffer << this_line
              this_line = lines.shift
            end

            if buffer.any? && admonition = buffer.first.match(/^NOTE:\s*/)
              buffer[0] = admonition.post_match
              block = Block.new(parent, :note, buffer)
            else
              block = Block.new(parent, :paragraph, buffer)
            end
          end
        end

        block.anchor  ||= anchor
        block.title   ||= title
        block.caption ||= caption

        block
      end

      # Private: Get the Integer section level based on the characters
      # used in the ASCII line under the section name.
      #
      # line - the String line from under the section name.
      def section_level(line)
        char = line.strip.chars.to_a.uniq
        case char
        when ['=']; 0
        when ['-']; 1
        when ['~']; 2
        when ['^']; 3
        when ['+']; 4
        end
      end

      def is_section_heading?(line1, line2)
        !line1.nil? && !line2.nil? && line1.match(REGEXP[:name]) && line2.match(REGEXP[:line]) && (line1.size - line2.size).abs <= 1
      end

      # Private: Return the next section from the document.
      #
      # Examples
      #
      #   source
      #   => "GREETINGS\n---------\nThis is my doc.\n\nSALUTATIONS\n-----------\nIt is awesome."
      #
      #   doc = Asciidoc.new(source)
      #
      #   doc.next_section
      #   ["GREETINGS", [:paragraph, "This is my doc."]]
      #
      #   doc.next_section
      #   ["SALUTATIONS", [:paragraph, "It is awesome."]]
      def next_section(lines)
        section = Section.new(self)

        # Skip ahead to the next section definition
        while lines.any? && section.name.nil?
          this_line = lines.shift
          next_line = lines.first || ''
          if match = this_line.match(REGEXP[:anchor])
            section.anchor = match[1]
          elsif is_section_heading?(this_line, next_line)
            header = this_line.match(REGEXP[:name])
            if anchor = header[1].match(/^(.*)\[\[([^\]]+)\]\]\s*$/)
              section.name   = anchor[1]
              section.anchor = anchor[2]
            else
              section.name = header[1]
            end
            section.level = section_level(next_line)
            lines.shift
          end
        end

        if !section.anchor.nil?
          anchor_id = section.anchor.match(/^\[(.*)\]/) ? $1 : section.anchor
          @references[anchor_id] = section.anchor
          section.anchor = anchor_id
        end

        # Grab all the lines that belong to this section
        section_lines = []
        while lines.any?
          this_line = lines.shift
          next_line = lines.first

          if is_section_heading?(this_line, next_line)
            if section_level(next_line) <= section.level
              lines.unshift this_line
              lines.unshift section_lines.pop if section_lines.any? && section_lines.last.match(REGEXP[:anchor])
              break
            else
              section_lines << this_line
              section_lines << lines.shift
            end
          elsif this_line.match(REGEXP[:listing])
            section_lines << this_line
            this_line = lines.shift
            while !this_line.nil? && !this_line.match(REGEXP[:listing])
              section_lines << this_line
              this_line = lines.shift
            end
            section_lines << this_line unless this_line.nil?
          else
            section_lines << this_line
          end
        end

        while section_lines.any?
          while section_lines.any? && section_lines.first.strip.empty?
            section_lines.shift
          end

          section << next_block(section_lines, section) if section_lines.any?
        end

        section
      end

  end
end
