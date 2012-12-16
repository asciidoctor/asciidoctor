# Public: Methods to parse and build objects from Asciidoc lines
class Asciidoctor::Lexer

  include Asciidoctor

  # Public: Make sure the Lexer object doesn't get initialized.
  def initialize
    raise 'Au contraire, mon frere. No lexer instances will be running around.'
  end

  def self.document_from_parent(parent)
    if parent.is_a? Document
      parent
    else
      parent.document
    end
  end

  # Return the next block from the Reader.
  #
  # * Skip over blank lines to find the start of the next content block.
  # * Use defined regular expressions to determine the type of content block.
  # * Based on the type of content block, grab lines to the end of the block.
  # * Return a new Asciidoctor::Block or Asciidoctor::Section instance with the
  #   content set to the grabbed lines.
  def self.next_block(reader, parent = self)
    # Skip ahead to the block content
    reader.skip_blank

    return nil unless reader.has_lines?
    context = parent.is_a?(Block) ? parent.context : nil

    # NOTE: An anchor looks like this:
    #   [[foo]]
    # with the inside [foo] (including brackets) as match[1]
    if match = reader.peek_line.match(REGEXP[:anchor])
      Asciidoctor.debug "Found an anchor in line:\n\t#{reader.peek_line}"
      # NOTE: This expression conditionally strips off the brackets from
      # [foo], though REGEXP[:anchor] won't actually match without
      # match[1] being bracketed, so the condition isn't necessary.
      anchor = match[1].match(/^\[(.*)\]/) ? $1 : match[1]
      # NOTE: Set @references['foo'] = '[foo]'
      document_from_parent(parent).references[anchor] = match[1]
      reader.get_line
    else
      anchor = nil
    end

    # skip a list continuation character if we're processing a list
    if LIST_CONTEXTS.include?(context)
      reader.skip_list_continuation
    end

    Asciidoctor.debug "/"*64
    Asciidoctor.debug "#{File.basename(__FILE__)}:#{__LINE__} -> #{__method__} - First two lines are:"
    Asciidoctor.debug reader.peek_line
    tmp_line = reader.get_line
    Asciidoctor.debug reader.peek_line
    reader.unshift tmp_line
    Asciidoctor.debug "/"*64

    block = nil
    title = nil
    caption = nil
    buffer = []
    attributes = {}
    context = parent.is_a?(Block) ? parent.context : nil
    while reader.has_lines? && block.nil?
      buffer.clear
      this_line = reader.get_line
      next_line = reader.peek_line || ''

      if this_line.match(REGEXP[:comment_blk])
        Reader.new(reader.grab_lines_until {|line| line.match( REGEXP[:comment_blk] ) })

      elsif this_line.match(REGEXP[:comment])
        reader.skip_blank

      elsif match = this_line.match(REGEXP[:attr_list_blk])
        collect_attributes(match[1], attributes)
        reader.skip_blank

      elsif is_section_heading?(this_line, next_line)
        # If we've come to a new section, then we've found the end of this
        # current block.  Likewise if we'd found an unassigned anchor, push
        #
        # FIXME when slurping up next section, give back trailing anchor to following section
        reader.unshift(this_line)
        Asciidoctor.debug "#{__method__}: SENDING to next_section with lines[0] = #{reader.peek_line}"
        block = next_section(reader, parent)

      elsif match = this_line.match(REGEXP[:title])
        title = match[1]
        reader.skip_blank

      elsif match = this_line.match(REGEXP[:image_blk])
        collect_attributes(match[2], attributes, ['alt', 'width', 'height'])
        block = Block.new(parent, :image)
        # FIXME this seems kind of one-off here
        target = block.sub_attributes(match[1])
        attributes['target'] = target
        attributes['alt'] ||= File.basename(target, File.extname(target))
        reader.skip_blank

      elsif this_line.match(REGEXP[:oblock])
        # oblock is surrounded by '--' lines and has zero or more blocks inside
        buffer = Reader.new(reader.grab_lines_until { |line| line.match(REGEXP[:oblock]) })

        # Strip lines off end of block - not implemented yet
        # while buffer.has_lines? && buffer.last.strip.empty?
        #   buffer.pop
        # end

        block = Block.new(parent, :oblock, [])
        while buffer.has_lines?
          new_block = next_block(buffer, block)
          block.blocks << new_block unless new_block.nil?
        end

      # needs to come before list detection
      elsif this_line.match(REGEXP[:sidebar_blk])
        # sidebar is surrounded by '****' (4 or more '*' chars) lines
        # FIXME violates DRY because it's a duplication of quote parsing
        block = Block.new(parent, :sidebar)
        buffer = Reader.new(reader.grab_lines_until {|line| line.match( REGEXP[:sidebar_blk] ) })

        while buffer.has_lines?
          new_block = next_block(buffer, block)
          block.blocks << new_block unless new_block.nil?
        end

      elsif list_type = [:olist, :colist].detect{|l| this_line.match( REGEXP[l] )}
        items = []
        Asciidoctor.debug "Creating block of type: #{list_type}"
        block = Block.new(parent, list_type)
        attributes['style'] ||= 'arabic'
        while !this_line.nil? && match = this_line.match(REGEXP[list_type])
          item = ListItem.new(block)

          reader.unshift match[2].lstrip.sub(/^\./, '\.')
          item_segment = Reader.new(list_item_segment(reader, :alt_ending => REGEXP[list_type]))
          while item_segment.has_lines?
            new_block = next_block(item_segment, block)
            item.blocks << new_block unless new_block.nil?
          end

          item.fold_first

          items << item

          reader.skip_blank

          this_line = reader.get_line
        end
        reader.unshift(this_line) unless this_line.nil?

        block.buffer = items

      elsif match = this_line.match(REGEXP[:ulist])
        reader.unshift(this_line)
        block = build_ulist(reader, parent)

      elsif match = this_line.match(REGEXP[:dlist])
        # TODO build_dlist method?
        pairs = []
        block = Block.new(parent, :dlist)
        # allows us to capture until we find a labeled item using the same delimiter (::, :::, :::: or ;;)
        sibling_matcher = REGEXP[:dlist_siblings][match[3]]

        begin
          dt = ListItem.new(block, match[2])
          dt.anchor = match[1] unless match[1].nil?
          dd = ListItem.new(block, match[5])

          dd_segment = Reader.new(list_item_segment(reader, :alt_ending => sibling_matcher))
          while dd_segment.has_lines?
            new_block = next_block(dd_segment, block)
            dd.blocks << new_block unless new_block.nil?
          end

          dd.fold_first

          pairs << [dt, dd]

          # this skip_blank might be redundant
          reader.skip_blank
          this_line = reader.get_line
        end while !this_line.nil? && match = this_line.match(sibling_matcher)

        reader.unshift(this_line) unless this_line.nil?
        block.buffer = pairs
    
      # FIXME violates DRY because it's a duplication of other block parsing
      elsif this_line.match(REGEXP[:example])
        # example is surrounded by lines with 4 or more '=' chars
        rekey_positional_attributes(attributes, ['style'])
        if admonition_style = ADMONITION_STYLES.detect {|s| attributes['style'] == s}
          block = Block.new(parent, :admonition)
          attributes['name'] = admonition_style.downcase
          attributes['caption'] ||= admonition_style.capitalize
        else
          block = Block.new(parent, :example)
        end
        buffer = Reader.new(reader.grab_lines_until {|line| line.match( REGEXP[:example] ) })

        while buffer.has_lines?
          new_block = next_block(buffer, block)
          block.blocks << new_block unless new_block.nil?
        end

      # FIXME violates DRY w/ non-delimited block listing
      elsif this_line.match(REGEXP[:listing])
        rekey_positional_attributes(attributes, ['style', 'language', 'linenums'])
        buffer = reader.grab_lines_until {|line| line.match( REGEXP[:listing] )}
        block = Block.new(parent, :listing, buffer)

      elsif this_line.match(REGEXP[:quote])
        # multi-line verse or quote is surrounded by a block delimiter
        rekey_positional_attributes(attributes, ['style', 'attribution', 'citetitle'])
        quote_context = (attributes['style'] == 'verse' ? :verse : :quote)
        buffer = Reader.new(reader.grab_lines_until {|line| line.match( REGEXP[:quote] ) })

        # only quote can have other section elements (as as section block)
        section_body = (quote_context == :quote)

        if section_body
          block = Block.new(parent, quote_context)
          while buffer.has_lines?
            new_block = next_block(buffer, block)
            block.blocks << new_block unless new_block.nil?
          end
        else
          block = Block.new(parent, quote_context, buffer.lines)
        end

      elsif this_line.match(REGEXP[:lit_blk])
        # example is surrounded by '....' (4 or more '.' chars) lines
        buffer = reader.grab_lines_until {|line| line.match( REGEXP[:lit_blk] ) }
        block = Block.new(parent, :literal, buffer)

      elsif this_line.match(REGEXP[:lit_par])
        # literal paragraph is contiguous lines starting with
        # one or more space or tab characters

        # So we need to actually include this one in the grab_lines group
        reader.unshift this_line
        buffer = reader.grab_lines_until(:preserve_last_line => true) {|line|
          (context == :dlist && line.match(REGEXP[:dlist])) || !line.match(REGEXP[:lit_par])
        }

        # trim off the indentation that put us in this literal paragraph
        if !buffer.empty? && match = buffer.first.match(/^([[:blank:]]+)/)
          offset = match[1].length
          buffer = buffer.map {|l| l.slice(offset..-1)}
        end

        block = Block.new(parent, :literal, buffer)

      ## these switches based on style need to come immediately before the else ##

      elsif attributes[0] == 'source'
        rekey_positional_attributes(attributes, ['style', 'language', 'linenums'])
        reader.unshift(this_line)
        buffer = reader.grab_lines_until(:break_on_blank_lines => true)
        block = Block.new(parent, :listing, buffer)

      elsif admonition_style = ADMONITION_STYLES.detect{|s| attributes[0] == s}
        # an admonition preceded by [*TYPE*] and lasts until a blank line
        reader.unshift(this_line)
        buffer = reader.grab_lines_until(:break_on_blank_lines => true)
        block = Block.new(parent, :admonition, buffer)
        attributes['style'] = admonition_style
        attributes['name'] = admonition_style.downcase
        attributes['caption'] ||= admonition_style.capitalize

      elsif quote_context = [:quote, :verse].detect{|s| attributes[0] == s.to_s}
        # single-paragraph verse or quote is preceded by [verse] or [quote], respectively, and lasts until a blank line
        rekey_positional_attributes(attributes, ['style', 'attribution', 'citetitle'])
        reader.unshift(this_line)
        buffer = reader.grab_lines_until(:break_on_blank_lines => true)
        block = Block.new(parent, quote_context, buffer)

      else
        # paragraph is contiguous nonblank/noncontinuation lines
        reader.unshift this_line
        buffer = reader.grab_lines_until(:break_on_blank_lines => true, :preserve_last_line => true) {|line|
          (context == :dlist && line.match(REGEXP[:dlist])) ||
          ([:ulist, :olist, :dlist].include?(context) && line.chomp == LIST_CONTINUATION) ||
          line.match(REGEXP[:oblock])
        }

        if LIST_CONTEXTS.include?(context)
          reader.skip_list_continuation
        end

        if !buffer.empty? && admonition = buffer.first.match(Regexp.new('^(' + ADMONITION_STYLES.join('|') + '):\s+'))
          buffer[0] = admonition.post_match
          block = Block.new(parent, :admonition, buffer)
          attributes['style'] = admonition[1]
          attributes['name'] = admonition[1].downcase
          attributes['caption'] ||= admonition[1].capitalize
        else
          Asciidoctor.debug "Proud parent #{parent} getting a new paragraph with buffer: #{buffer}"
          block = Block.new(parent, :paragraph, buffer)
        end
      end
    end

    # when looking for nested content, a series of
    # line comments or a comment block could leave us
    # without a block
    if !block.nil?
      block.anchor   ||= (anchor || attributes['id'])
      block.title    ||= title
      block.caption  ||= caption
      block.update_attributes(attributes)
    end

    block
  end

  # Private: Return the Array of lines constituting the next list item
  #          segment, removing them from the 'lines' Array passed in.
  #
  # reader  - the Reader instance from which to get input.
  # options - an optional Hash of processing options:
  #           * :alt_ending may be used to specify a regular expression match
  #             other than a blank line to signify the end of the segment.
  #           * :list_types may be used to specify list item patterns to
  #             include. May be either a single Symbol or an Array of Symbols.
  #           * :list_level may be used to specify a mimimum list item level
  #             to include. If this is specified, then break if we find a list
  #             item of a lower level.
  #
  # Returns the Array of lines forming the next segment.
  #
  # Examples
  #
  #   reader = Asciidoctor::Reader.new(
  #      ["First paragraph\n", "+\n", "Second paragraph\n", "--\n",
  #       "Open block\n", "\n", "Can have blank lines\n", "--\n", "\n",
  #       "In a different segment\n"])
  #
  #   list_item_segment(reader)
  #   => ["First paragraph\n", "+\n", "Second paragraph\n", "--\n",
  #       "Open block\n", "\n", "Can have blank lines\n", "--\n"]
  #
  #   reader.peek_line
  #   => "In a different segment\n"
  def self.list_item_segment(reader, options={})
    alternate_ending = options[:alt_ending]
    list_types = Array(options[:list_types]) || [:ulist, :olist, :colist, :dlist]
    list_level = options[:list_level].to_i

    # We know we want to include :lit_par types, even if we have specified,
    # say, only :ulist type list entries.
    list_types << :lit_par unless list_types.include? :lit_par
    segment = []

    reader.skip_blank

    # Grab lines until the first blank line not inside an open block
    # or listing
    in_oblock = false
    in_listing = false
    while reader.has_lines?
      this_line = reader.get_line
      Asciidoctor.debug "----->  Processing: #{this_line}"
      in_oblock = !in_oblock if this_line.match(REGEXP[:oblock])
      in_listing = !in_listing if this_line.match(REGEXP[:listing])
      if !in_oblock && !in_listing
        if this_line.strip.empty?
          # TODO  - FIX THIS BEFORE ANY MORE KITTENS DIE AUGGGHHH!!!
          next_nonblank = reader.instance_variable_get(:@lines).detect{|l| !l.strip.empty?}

          # If there are blank lines ahead, but there's at least one
          # more non-blank line that doesn't trigger an alternate_ending
          # for the block of lines, then vacuum up all the blank lines
          # into this segment and continue with the next non-blank line.
          if next_nonblank &&
             ( alternate_ending.nil? ||
               !next_nonblank.match(alternate_ending)
             ) && list_types.find { |list_type| next_nonblank.match(REGEXP[list_type]) }

             while reader.has_lines? and reader.peek_line.strip.empty?
               segment << this_line
               this_line = reader.get_line
             end
          else
            break
          end

        # Have we come to a line matching an alternate_ending regexp?
        elsif alternate_ending && this_line.match(alternate_ending)
          reader.unshift this_line
          break

        # Do we have a minimum list_level, and have come to a list item
        # line with a lower level?
        elsif list_level &&
              list_types.find { |list_type| this_line.match(REGEXP[list_type]) } &&
              ($1.length < list_level)
          reader.unshift this_line
          break
        end

        # From the Asciidoc user's guide:
        #   Another list or a literal paragraph immediately following
        #   a list item will be implicitly included in the list item

        # Thus, the list_level stuff may be wrong here.
      end

      segment << this_line
    end

    Asciidoctor.debug "*"*40
    Asciidoctor.debug "#{File.basename(__FILE__)}:#{__LINE__} -> #{__method__}: Returning this:"
    #Asciidoctor.debug segment.inspect
    Asciidoctor.debug "*"*10
    Asciidoctor.debug "Leaving #{__method__}: Top of reader queue is:"
    Asciidoctor.debug reader.peek_line
    Asciidoctor.debug "*"*40
    segment
  end

  # Private: Get the Integer ulist level based on the characters
  # in front of the list item text.
  #
  # line - the String line containing the list item
  def self.ulist_level(line)
    if m = line.strip.match(/^(- | \*{1,5})\s+/x)
      return m[1].length
    end
  end

  def self.build_ulist_item(reader, block, match = nil)
    list_type = :ulist
    this_line = reader.get_line
    return nil unless this_line

    match ||= this_line.match(REGEXP[list_type])
    if match.nil?
      reader.unshift(this_line)
      return nil
    end

    level = match[1].length

    list_item = ListItem.new(block)
    list_item.level = level
    Asciidoctor.debug "#{__FILE__}:#{__LINE__}: Created ListItem #{list_item} with match[2]: #{match[2]} and level: #{list_item.level}"

    # Restore first line of list item
    # Also prevent bullet list text starting with . from being treated as a paragraph
    # title or some other unseemly thing in list_item_segment. I think. (NOTE)
    reader.unshift match[2].lstrip.sub(/^\./, '\.')

    item_segment = Reader.new(list_item_segment(reader, :alt_ending => REGEXP[list_type]))
#    item_segment = list_item_segment(reader)
    while item_segment.has_lines?
      new_block = next_block(item_segment, block)
      list_item.blocks << new_block unless new_block.nil?
    end

    Asciidoctor.debug "\n\nlist_item has #{list_item.blocks.count} blocks, and first is a #{list_item.blocks.first.class} with context #{list_item.blocks.first.context rescue 'n/a'}\n\n"

    list_item.fold_first

    list_item
  end

  def self.build_ulist(reader, parent = nil)
    items = []
    list_type = :ulist
    block = Block.new(parent, list_type)
    Asciidoctor.debug "Created :ulist block: #{block}"
    first_item_level = nil

    while reader.has_lines? && match = reader.peek_line.match(REGEXP[list_type])

      this_item_level = match[1].length

      if first_item_level && first_item_level < this_item_level
        # If this next :uline level is down one from the
        # current Block's, append it to content of the current list item
        items.last.blocks << next_block(reader, block)
      elsif first_item_level && first_item_level > this_item_level
        break
      else
        list_item = build_ulist_item(reader, block, match)
        # Set the base item level for this Block
        first_item_level ||= list_item.level
      end

      items << list_item unless list_item.nil?
      list_item = nil

      reader.skip_blank
    end

    block.buffer = items
    block
  end

  def self.build_ulist_ref(lines, parent = nil)
    items = []
    list_type = :ulist
    block = Block.new(parent, list_type)
    Asciidoctor.debug "Created :ulist block: #{block}"
    last_item_level = nil
    this_line = lines.shift

    while this_line && match = this_line.match(REGEXP[list_type])
      level = match[1].length

      list_item = ListItem.new(block)
      list_item.level = level
      Asciidoctor.debug "Created ListItem #{list_item} with match[2]: #{match[2]} and level: #{list_item.level}"

      lines.unshift match[2].lstrip.sub(/^\./, '\.')
      item_segment = list_item_segment(lines, :alt_ending => REGEXP[list_type], :list_level => level)
      while item_segment.any?
        new_block = next_block(item_segment, block)
        list_item.blocks << new_block unless new_block.nil?
      end

      list_item.fold_first

      if items.any? && (level > items.last.level)
        Asciidoctor.debug "--> Putting this new level #{level} ListItem under my pops, #{items.last} (level: #{items.last.level})"
        items.last.blocks << list_item
      else
        Asciidoctor.debug "Stacking new list item in parent block's blocks"
        items << list_item
      end

      last_item_level = list_item.level

      # TODO: This has to come from a Reader object
      skip_blank(lines)

      this_line = lines.shift
    end
    lines.unshift(this_line) unless this_line.nil?

    block.buffer = items
    block
  end

  def self.collect_attributes(attrs, attributes, posattrs = [])
    # TODO walk be properly rather than using split
    attrs.split(/\s*,\s*/).each_with_index do |entry, i|
      key, val = entry.split(/\s*=\s*/) 
      if !val.nil?
        val.gsub!(/^(['"])(.*)\1$/, '\2') unless val.nil?
        attributes[key] = val
      else
        attributes[i] = key
        # positional attribute has a known key
        if posattrs.size >= (i + 1)
          attributes[posattrs[i]] = key
        end 
      end
    end
  end

  def self.rekey_positional_attributes(attributes, posattrs)
    posattrs.each_with_index do |key, i|
      val = attributes[i]
      if !val.nil?
        attributes[key] = val
      end
    end
  end

  # Private: Get the Integer section level based on the characters
  # used in the ASCII line under the section name.
  #
  # line - the String line from under the section name.
  def self.section_level(line)
    char = line.strip.chars.to_a.uniq
    case char
    when ['=']; 0
    when ['-']; 1
    when ['~']; 2
    when ['^']; 3
    when ['+']; 4
    end
  end

  # == is level 0, === is level 1, etc.
  def self.single_line_section_level(line)
    [line.length - 1, 0].max
  end

  def self.is_single_line_section_heading?(line)
    !line.nil? && line.match(REGEXP[:level_title])
  end

  def self.is_two_line_section_heading?(line1, line2)
    !line1.nil? && !line2.nil? &&
    line1.match(REGEXP[:name]) && line2.match(REGEXP[:line]) &&
    # chomp so that a (non-visible) endline does not impact calculation
    (line1.chomp.size - line2.chomp.size).abs <= 1
  end

  def self.is_section_heading?(line1, line2 = nil)
    is_single_line_section_heading?(line1) ||
    is_two_line_section_heading?(line1, line2)
  end

  # Private: Extracts the name, level and (optional) embedded anchor from a
  #          1- or 2-line section heading.
  #
  # Returns an array of a String, Integer, and String or nil.
  #
  # Examples
  #
  #   line1
  #   => "Foo\n"
  #   line2
  #   => "~~~\n"
  #
  #   name, level, anchor = extract_section_heading(line1, line2)
  #
  #   name
  #   => "Foo"
  #   level
  #   => 2
  #   anchor
  #   => nil
  #
  #   line1
  #   => "==== Foo\n"
  #
  #   name, level, anchor = extract_section_heading(line1)
  #
  #   name
  #   => "Foo"
  #   level
  #   => 3
  #   anchor
  #   => nil
  #
  def self.extract_section_heading(line1, line2 = nil)
    Asciidoctor.debug "#{__method__} -> line1: #{line1.chomp rescue 'nil'}, line2: #{line2.chomp rescue 'nil'}"
    sect_name = sect_anchor = nil
    sect_level = 0

    if is_single_line_section_heading?(line1)
      header_match = line1.match(REGEXP[:level_title])
      sect_name = header_match[2]
      sect_level = single_line_section_level(header_match[1])
    elsif is_two_line_section_heading?(line1, line2)
      header_match = line1.match(REGEXP[:name])
      if anchor_match = header_match[1].match(REGEXP[:anchor_embedded])
        sect_name   = anchor_match[1]
        sect_anchor = anchor_match[2]
      else
        sect_name = header_match[1]
      end
      sect_level = section_level(line2)
    end
    Asciidoctor.debug "#{__method__} -> Returning #{sect_name}, #{sect_level} (anchor: '#{sect_anchor || '<none>'}')"
    return [sect_name, sect_level, sect_anchor]
  end

  # Private: Return the next section from the Reader.
  #
  # Examples
  #
  #   source
  #   => "GREETINGS\n---------\nThis is my doc.\n\nSALUTATIONS\n-----------\nIt is awesome."
  #
  #   TODO: doc = Asciidoctor::Document.new(source)
  #
  #   doc.next_section
  #   ["GREETINGS", [:paragraph, "This is my doc."]]
  #
  #   doc.next_section
  #   ["SALUTATIONS", [:paragraph, "It is awesome."]]
  def self.next_section(reader, parent = self)
    section = Section.new(parent)

    Asciidoctor.debug "%"*64
    Asciidoctor.debug "#{File.basename(__FILE__)}:#{__LINE__} -> #{__method__} - First two lines are:"
    Asciidoctor.debug reader.peek_line
    tmp_line = reader.get_line
    Asciidoctor.debug reader.peek_line
    reader.unshift tmp_line
    Asciidoctor.debug "%"*64

    # Skip ahead to the next section definition
    while reader.has_lines? && section.name.nil?
      this_line = reader.get_line
      next_line = reader.peek_line || ''
      if match = this_line.match(REGEXP[:anchor])
        section.anchor = match[1]
      elsif is_section_heading?(this_line, next_line)
        section.name, section.level, section.anchor = extract_section_heading(this_line, next_line)
        reader.get_line unless is_single_line_section_heading?(this_line)
      end
    end

    if !section.anchor.nil?
      anchor_id = section.anchor.match(/^\[(.*)\]/) ? $1 : section.anchor
      document_from_parent(parent).references[anchor_id] = section.anchor
      section.anchor = anchor_id
    end

    # Grab all the lines that belong to this section
    section_lines = []
    while reader.has_lines?
      this_line = reader.get_line
      next_line = reader.peek_line

      if is_section_heading?(this_line, next_line)
        _, this_level, _ = extract_section_heading(this_line, next_line)

        if this_level <= section.level
          # A section can't contain a section level lower than itself,
          # so this signifies the end of the section.
          reader.unshift this_line
          if section_lines.any? && section_lines.last.match(REGEXP[:anchor])
            # Put back the anchor that came before this new-section line
            # on which we're bailing.
            reader.unshift section_lines.pop
          end
          break
        else
          section_lines << this_line
          section_lines << reader.get_line unless is_single_line_section_heading?(this_line)
        end
      else
        section_lines << this_line
      end
    end

    section_reader = Reader.new(section_lines)
    # Now parse section_lines into Blocks belonging to the current Section
    while section_reader.has_lines?
      section_reader.skip_blank

      if section_reader.has_lines?
        new_block = next_block(section_reader, section)
        section << new_block unless new_block.nil?
      end
    end

    # detect preamble and push it into a block
    # QUESTION make this an operation on Section?
    if section.level == 0
      blocks = section.blocks.take_while {|b| !b.is_a? Section}
      if !blocks.empty?
        # QUESTION Should we propagate the buffer?
        #preamble = Block.new(section, :preamble, blocks.reduce {|a, b| a.buffer + b.buffer})
        preamble = Block.new(section, :preamble)
        blocks.each { preamble << section.delete_at(0) }
        section.insert(0, preamble)
      end
    end

    section
  end

end
