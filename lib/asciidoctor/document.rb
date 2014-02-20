module Asciidoctor
# Public: Methods for parsing and converting AsciiDoc documents.
#
# There are several strategies for getting the title of the document:
#
# doctitle - value of title attribute, if assigned and non-empty,
#            otherwise title of first section in document, if present
#            otherwise nil
# name - an alias of doctitle
# title - value of the title attribute, or nil if not present
# first_section.title - title of first section in document, if present
# header.title - title of section level 0
#
# Keep in mind that you'll want to honor these document settings:
#
# notitle  - The h1 heading should not be shown
# noheader - The header block (h1 heading, author, revision info) should not be shown
# nofooter - the footer block should not be shown
class Document < AbstractBlock

  Footnote = Struct.new :index, :id, :text

  class AttributeEntry
    attr_reader :name, :value, :negate

    def initialize name, value, negate = nil
      @name = name
      @value = value
      @negate = negate.nil? ? value.nil? : negate
    end

    def save_to block_attributes
      (block_attributes[:attribute_entries] ||= []) << self
    end
  end

  # Public A read-only integer value indicating the level of security that
  # should be enforced while processing this document. The value must be
  # set in the Document constructor using the :safe option.
  #
  # A value of 0 (UNSAFE) disables any of the security features enforced
  # by Asciidoctor (Ruby is still subject to its own restrictions).
  #
  # A value of 1 (SAFE) closely parallels safe mode in AsciiDoc. In particular,
  # it prevents access to files which reside outside of the parent directory
  # of the source file and disables any macro other than the include macro.
  #
  # A value of 10 (SERVER) disallows the document from setting attributes that
  # would affect the conversion of the document, in addition to all the security
  # features of SafeMode::SAFE. For instance, this value disallows changing the
  # backend or the source-highlighter using an attribute defined in the source
  # document. This is the most fundamental level of security for server-side
  # deployments (hence the name).
  #
  # A value of 20 (SECURE) disallows the document from attempting to read files
  # from the file system and including the contents of them into the document,
  # in addition to all the security features of SafeMode::SECURE. In
  # particular, it disallows use of the include::[] macro and the embedding of
  # binary content (data uri), stylesheets and JavaScripts referenced by the
  # document. (Asciidoctor and trusted extensions may still be allowed to embed
  # trusted content into the document).
  #
  # Since Asciidoctor is aiming for wide adoption, 20 (SECURE) is the default
  # value and is recommended for server-side deployments.
  #
  # A value of 100 (PARANOID) is planned to disallow the use of passthrough
  # macros and prevents the document from setting any known attributes in
  # addition to all the security features of SafeMode::SECURE. Please note that
  # this level is not currently implemented (and therefore not enforced)!
  attr_reader :safe

  # Public: Get the Hash of document references
  attr_reader :references

  # Public: Get the Hash of document counters
  attr_reader :counters

  # Public: Get the Hash of callouts
  attr_reader :callouts

  # Public: The section level 0 block
  attr_reader :header

  # Public: Base directory for converting this document. Defaults to directory of the source file.
  # If the source is a string, defaults to the current directory.
  attr_reader :base_dir

  # Public: A reference to the parent document of this nested document.
  attr_reader :parent_document

  # Public: The Converter associated with this document
  attr_reader :converter

  # Public: The extensions registry
  attr_reader :extensions

  # Public: Initialize an Asciidoc object.
  #
  # data    - The Array of Strings holding the Asciidoc source document. (default: [])
  # options - A Hash of options to control processing, such as setting the safe mode (:safe),
  #           suppressing the header/footer (:header_footer) and attribute overrides (:attributes)
  #           (default: {})
  #
  # Examples
  #
  #   data = File.readlines(filename)
  #   doc  = Asciidoctor::Document.new(data)
  #   puts doc.convert
  def initialize(data = [], options = {})
    super(self, :document)

    if options[:parent]
      @parent_document = options.delete(:parent)
      options[:base_dir] ||= @parent_document.base_dir
      @references = @parent_document.references.inject({}) do |collector,(key,ref)|
        if key == :footnotes
          collector[:footnotes] = []
        else
          collector[key] = ref
        end
        collector
      end
      # QUESTION should we support setting attribute in parent document from nested document?
      # NOTE we must dup or else all the assignments to the overrides clobbers the real attributes
      @attribute_overrides = @parent_document.attributes.dup
      @attribute_overrides.delete 'doctype'
      @safe = @parent_document.safe
      @converter = @parent_document.converter
      initialize_extensions = false
      @extensions = @parent_document.extensions
    else
      @parent_document = nil
      @references = {
        :ids => {},
        :footnotes => [],
        :links => [],
        :images => [],
        :indexterms => [],
        :includes => ::Set.new,
      }
      # copy attributes map and normalize keys
      # attribute overrides are attributes that can only be set from the commandline
      # a direct assignment effectively makes the attribute a constant
      # a nil value or name with leading or trailing ! will result in the attribute being unassigned
      overrides = {}
      (options[:attributes] || {}).each do |key, value|
        if key.start_with?('!')
          key = key[1..-1]
          value = nil
        elsif key.end_with?('!')
          key = key.chop
          value = nil
        end
        overrides[key.downcase] = value
      end
      @attribute_overrides = overrides
      @safe = nil
      @converter = nil
      initialize_extensions = defined? ::Asciidoctor::Extensions
      @extensions = nil # initialize furthur down
    end

    @header = nil
    @counters = {}
    @callouts = Callouts.new
    @attributes_modified = ::Set.new
    @options = options
    unless @parent_document
      # safely resolve the safe mode from const, int or string
      if !@safe && !(safe_mode = options[:safe])
        @safe = SafeMode::SECURE
      elsif safe_mode.is_a?(::Fixnum)
        # be permissive in case API user wants to define new levels
        @safe = safe_mode
      else
        begin
          @safe = SafeMode.const_get(safe_mode.to_s.upcase).to_i
        rescue
          @safe = SafeMode::SECURE.to_i
        end
      end
    end
    options[:header_footer] ||= false

    @attributes['encoding'] = 'UTF-8'
    @attributes['sectids'] = ''
    @attributes['notitle'] = '' unless options[:header_footer]
    @attributes['toc-placement'] = 'auto'
    @attributes['stylesheet'] = ''
    @attributes['copycss'] = '' if options[:header_footer]
    @attributes['prewrap'] = ''
    @attributes['attribute-undefined'] = Compliance.attribute_undefined
    @attributes['attribute-missing'] = Compliance.attribute_missing

    # language strings
    # TODO load these based on language settings
    @attributes['caution-caption'] = 'Caution'
    @attributes['important-caption'] = 'Important'
    @attributes['note-caption'] = 'Note'
    @attributes['tip-caption'] = 'Tip'
    @attributes['warning-caption'] = 'Warning'
    @attributes['appendix-caption'] = 'Appendix'
    @attributes['example-caption'] = 'Example'
    @attributes['figure-caption'] = 'Figure'
    #@attributes['listing-caption'] = 'Listing'
    @attributes['table-caption'] = 'Table'
    @attributes['toc-title'] = 'Table of Contents'
    @attributes['manname-title'] = 'NAME'
    @attributes['untitled-label'] = 'Untitled'
    @attributes['version-label'] = 'Version'
    @attributes['last-update-label'] = 'Last updated'

    @attribute_overrides['asciidoctor'] = ''
    @attribute_overrides['asciidoctor-version'] = VERSION

    safe_mode_name = SafeMode.constants.detect {|l| SafeMode.const_get(l) == @safe}.to_s.downcase
    @attribute_overrides['safe-mode-name'] = safe_mode_name
    @attribute_overrides["safe-mode-#{safe_mode_name}"] = ''
    @attribute_overrides['safe-mode-level'] = @safe

    # sync the embedded attribute w/ the value of options...do not allow override
    @attribute_overrides['embedded'] = options[:header_footer] ? nil : ''

    # the only way to set the max-include-depth attribute is via the document options
    # 64 is the AsciiDoc default
    @attribute_overrides['max-include-depth'] ||= 64

    # the only way to enable uri reads is via the document options, disabled by default
    unless !@attribute_overrides['allow-uri-read'].nil?
      @attribute_overrides['allow-uri-read'] = nil
    end

    @attribute_overrides['user-home'] = USER_HOME

    # if the base_dir option is specified, it overrides docdir as the root for relative paths
    # otherwise, the base_dir is the directory of the source file (docdir) or the current
    # directory of the input is a string
    if !options[:base_dir]
      if @attribute_overrides['docdir']
        @base_dir = @attribute_overrides['docdir'] = ::File.expand_path(@attribute_overrides['docdir'])
      else
        #warn 'asciidoctor: WARNING: setting base_dir is recommended when working with string documents' unless nested?
        @base_dir = @attribute_overrides['docdir'] = ::File.expand_path(::Dir.pwd)
      end
    else
      @base_dir = @attribute_overrides['docdir'] = ::File.expand_path(options[:base_dir])
    end

    # allow common attributes backend and doctype to be set using options hash
    if (value = options[:backend])
      @attribute_overrides['backend'] = %(#{value})
    end

    if (value = options[:doctype])
      @attribute_overrides['doctype'] = %(#{value})
    end

    if @safe >= SafeMode::SERVER
      # restrict document from setting copycss, source-highlighter and backend
      @attribute_overrides['copycss'] ||= nil
      @attribute_overrides['source-highlighter'] ||= nil
      @attribute_overrides['backend'] ||= DEFAULT_BACKEND
      # restrict document from seeing the docdir and trim docfile to relative path
      if !@parent_document && @attribute_overrides.has_key?('docfile')
        @attribute_overrides['docfile'] = @attribute_overrides['docfile'][(@attribute_overrides['docdir'].length + 1)..-1]
      end
      @attribute_overrides['docdir'] = ''
      @attribute_overrides['user-home'] = '.'
      if @safe >= SafeMode::SECURE
        # assign linkcss (preventing css embedding) unless explicitly disabled from the commandline or API
        # effectively the same has "has key 'linkcss' and value == nil"
        unless @attribute_overrides.fetch('linkcss', '').nil?
          @attribute_overrides['linkcss'] = ''
        end
        # restrict document from enabling icons
        @attribute_overrides['icons'] ||= nil
      end
    end
    
    @attribute_overrides.delete_if {|key, val|
      verdict = false
      # a nil value undefines the attribute 
      if val.nil?
        @attributes.delete(key)
      # a negative key (trailing !) undefines the attribute
      # NOTE already normalize above as key with nil value
      #elsif key.end_with? '!'
      #  @attributes.delete(key[0..-2])
      # a negative key (leading !) undefines the attribute
      # NOTE already normalize above as key with nil value
      #elsif key.start_with? '!'
      #  @attributes.delete(key[1..-1])
      # otherwise it's an attribute assignment
      else
        # a value ending in @ indicates this attribute does not override
        # an attribute with the same key in the document souce
        if val.is_a?(::String) && val.end_with?('@')
          val = val.chop
          verdict = true
        end
        @attributes[key] = val
      end
      verdict
    }

    if @parent_document
      # don't need to do the extra processing within our own document
      # FIXME line info isn't reported correctly within include files in nested document
      @reader = Reader.new data, options[:cursor]
    else
      # setup default backend and doctype
      @attributes['backend'] ||= DEFAULT_BACKEND
      @attributes['doctype'] ||= DEFAULT_DOCTYPE
      update_backend_attributes @attributes['backend'], true

      #@attributes['indir'] = @attributes['docdir']
      #@attributes['infile'] = @attributes['docfile']

      # dynamic intrinstic attribute values
      now = Time.new
      @attributes['localdate'] ||= now.strftime('%Y-%m-%d')
      @attributes['localtime'] ||= now.strftime('%H:%M:%S %Z')
      @attributes['localdatetime'] ||= %(#{@attributes['localdate']} #{@attributes['localtime']})
      
      # docdate, doctime and docdatetime should default to
      # localdate, localtime and localdatetime if not otherwise set
      @attributes['docdate'] ||= @attributes['localdate']
      @attributes['doctime'] ||= @attributes['localtime']
      @attributes['docdatetime'] ||= @attributes['localdatetime']

      # fallback directories
      @attributes['stylesdir'] ||= '.'
      @attributes['iconsdir'] ||= File.join(@attributes.fetch('imagesdir', './images'), 'icons')

      @extensions = if initialize_extensions
        registry = if (ext_registry = options[:extensions_registry])
          if (ext_registry.is_a? Extensions::Registry) ||
              (::RUBY_ENGINE_JRUBY && (ext_registry.is_a? ::AsciidoctorJ::Extensions::ExtensionRegistry))
            ext_registry
          end
        elsif (ext_block = options[:extensions]) && (ext_block.is_a? ::Proc)
          Extensions.build_registry(&ext_block)
        end
        (registry ||= Extensions::Registry.new).activate self
      end

      @reader = PreprocessorReader.new self, data, Reader::Cursor.new(@attributes['docfile'], @base_dir)

      if @extensions && @extensions.preprocessors?
        @extensions.preprocessors.each do |ext|
          @reader = ext.process_method[self, @reader] || @reader
        end
      end
    end

    # Now parse the lines in the reader into blocks
    Parser.parse @reader, self, :header_only => !!options[:parse_header_only]

    @callouts.rewind

    if @extensions && !@parent_document && @extensions.treeprocessors?
      @extensions.treeprocessors.each do |ext|
        ext.process_method[self]
      end
    end
  end

  # Public: Get the named counter and take the next number in the sequence.
  #
  # name  - the String name of the counter
  # seed  - the initial value as a String or Integer
  #
  # returns the next number in the sequence for the specified counter
  def counter(name, seed = nil)
    if (attr_is_seed = !(attr_val = @attributes[name]).nil_or_empty?) && @counters.has_key?(name)
      @counters[name] = nextval(attr_val)
    else
      if seed.nil?
        seed = nextval(attr_is_seed ? attr_val : 0)
      elsif seed.to_i.to_s == seed
        seed = seed.to_i
      end
      @counters[name] = seed
    end

    (@attributes[name] = @counters[name])
  end

  # Public: Increment the specified counter and store it in the block's attributes
  #
  # counter_name - the String name of the counter attribute
  # block        - the Block on which to save the counter
  #
  # returns the next number in the sequence for the specified counter
  def counter_increment(counter_name, block)
    val = counter(counter_name)
    AttributeEntry.new(counter_name, val).save_to(block.attributes)
    val
  end

  # Internal: Get the next value in the sequence.
  #
  # Handles both integer and character sequences.
  #
  # current - the value to increment as a String or Integer
  #
  # returns the next value in the sequence according to the current value's type
  def nextval(current)
    if current.is_a?(::Integer)
      current + 1
    else
      intval = current.to_i
      if intval.to_s != current.to_s
        (current[0].ord + 1).chr
      else
        intval + 1 
      end
    end
  end

  def register(type, value)
    case type
    when :ids
      if value.is_a?(::Array)
        @references[:ids][value[0]] = (value[1] || '[' + value[0] + ']')
      else
        @references[:ids][value] = '[' + value + ']'
      end
    when :footnotes, :indexterms
      @references[type] << value
    else
      if @options[:catalog_assets]
        @references[type] << value
      end
    end
  end

  def footnotes?
    not @references[:footnotes].empty?
  end

  def footnotes
    @references[:footnotes]
  end

  def nested?
    !!@parent_document
  end

  def embedded?
    # QUESTION should this be !@options[:header_footer] ?
    @attributes.has_key? 'embedded'
  end

  def extensions?
    !!@extensions
  end

  # Make the raw source for the Document available.
  def source
    @reader.source if @reader
  end

  # Make the raw source lines for the Document available.
  def source_lines
    @reader.source_lines if @reader
  end

  def doctype
    @doctype ||= @attributes['doctype']
  end

  def backend
    @backend ||= @attributes['backend']
  end

  def basebackend? base
    @attributes['basebackend'] == base
  end

  # The title explicitly defined in the document attributes
  def title
    @attributes['title']
  end

  def title=(title)
    @header ||= Section.new(self, 0)
    @header.title = title
  end

  # We need to be able to return some semblance of a title
  def doctitle(opts = {})
    if !(val = @attributes.fetch('title', '')).empty?
      val = title
    elsif (sect = first_section) && sect.title?
      val = sect.title
    else
      return
    end
    
    if opts[:sanitize] && val.include?('<')
      val.gsub(XmlSanitizeRx, '').tr_s(' ', ' ').strip
    else
      val
    end
  end
  alias :name :doctitle

  # Public: Convenience method to retrieve the document attribute 'author'
  #
  # returns the full name of the author as a String
  def author
    @attributes['author']
  end

  # Public: Convenience method to retrieve the document attribute 'revdate'
  #
  # returns the date of last revision for the document as a String
  def revdate
    @attributes['revdate']
  end

  def notitle
    !@attributes.has_key?('showtitle') && @attributes.has_key?('notitle')
  end

  def noheader
    @attributes.has_key? 'noheader'
  end

  def nofooter
    @attributes.has_key? 'nofooter'
  end

  # QUESTION move to AbstractBlock?
  def first_section
    has_header? ? @header : (@blocks || []).detect{|e| e.context == :section }
  end

  def has_header?
    @header ? true : false
  end
  alias :header? :has_header?

  # Public: Append a content Block to this Document.
  #
  # If the child block is a Section, assign an index to it.
  #
  # block - The child Block to append to this parent Block
  #
  # Returns nothing.
  def <<(block)
    super
    if block.context == :section
      assign_index block
    end
  end

  # Internal: called after the header has been parsed and before the content
  # will be parsed.
  #--
  # QUESTION should we invoke the Treeprocessors here, passing in a phase?
  # QUESTION is finalize_header the right name?
  def finalize_header unrooted_attributes, header_valid = true
    clear_playback_attributes unrooted_attributes
    save_attributes
    unrooted_attributes['invalid-header'] = true unless header_valid
    unrooted_attributes
  end
 
  # Internal: Branch the attributes so that the original state can be restored
  # at a future time.
  def save_attributes
    # enable toc and numbered by default in DocBook backend
    # NOTE the attributes_modified should go away once we have a proper attribute storage & tracking facility
    if @attributes['basebackend'] == 'docbook'
      @attributes['toc'] = '' unless attribute_locked?('toc') || @attributes_modified.include?('toc')
      @attributes['numbered'] = '' unless attribute_locked?('numbered') || @attributes_modified.include?('numbered')
    end

    unless @attributes.has_key?('doctitle') || !(val = doctitle)
      @attributes['doctitle'] = val
    end

    # css-signature cannot be updated after header attributes are processed
    if !@id && @attributes.has_key?('css-signature')
      @id = @attributes['css-signature']
    end

    toc_val = @attributes['toc']
    toc2_val = @attributes['toc2']
    toc_position_val = @attributes['toc-position']

    if (toc_val && (toc_val != '' || !toc_position_val.nil_or_empty?)) || toc2_val
      default_toc_position = 'left'
      default_toc_class = 'toc2'
      position = [toc_position_val, toc2_val, toc_val].find {|pos| !pos.nil_or_empty? }
      position = default_toc_position if !position && toc2_val
      @attributes['toc'] = ''
      case position
      when 'left', '<', '&lt;'
        @attributes['toc-position'] = 'left'
      when 'right', '>', '&gt;'
        @attributes['toc-position'] = 'right'
      when 'top', '^'
        @attributes['toc-position'] = 'top'
      when 'bottom', 'v'
        @attributes['toc-position'] = 'bottom'
      when 'preamble'
        @attributes.delete 'toc2'
        @attributes['toc-placement'] = 'preamble'
        default_toc_class = nil
        default_toc_position = nil
      when 'default'
        @attributes.delete 'toc2'
        default_toc_class = nil
        default_toc_position = 'default'
      end
      @attributes['toc-class'] ||= default_toc_class if default_toc_class
      @attributes['toc-position'] ||= default_toc_position if default_toc_position
    end

    @original_attributes = @attributes.dup

    # unfreeze "flexible" attributes
    unless nested?
      FLEXIBLE_ATTRIBUTES.each do |name|
        # turning a flexible attribute off should be permanent
        # (we may need more config if that's not always the case)
        if @attribute_overrides.has_key?(name) && !@attribute_overrides[name].nil?
          @attribute_overrides.delete(name)
        end
      end
    end
  end

  # Internal: Restore the attributes to the previously saved state
  def restore_attributes
    # QUESTION shouldn't this be a dup in case we convert again?
    @attributes = @original_attributes
  end

  # Internal: Delete any attributes stored for playback
  def clear_playback_attributes(attributes)
    attributes.delete(:attribute_entries)
  end

  # Internal: Replay attribute assignments at the block level
  def playback_attributes(block_attributes)
    if (entries = block_attributes[:attribute_entries])
      entries.each do |entry|
        if entry.negate
          @attributes.delete(entry.name)
        else
          @attributes[entry.name] = entry.value
        end
      end
    end
  end

  # Public: Set the specified attribute on the document if the name is not locked
  #
  # If the attribute is locked, false is returned. Otherwise, the value is
  # assigned to the attribute name after first performing attribute
  # substitutions on the value. If the attribute name is 'backend', then the
  # value of backend-related attributes are updated.
  #
  # name  - the String attribute name
  # value - the String attribute value
  #
  # returns true if the attribute was set, false if it was not set because it's locked
  def set_attribute(name, value)
    if attribute_locked?(name)
      false
    else
      case name
      when 'backend'
        update_backend_attributes apply_attribute_value_subs(value)
      when 'doctype'
        update_doctype_attributes apply_attribute_value_subs(value)
      else
        @attributes[name] = apply_attribute_value_subs(value)
      end
      @attributes_modified << name
      true
    end
  end

  # Public: Delete the specified attribute from the document if the name is not locked
  #
  # If the attribute is locked, false is returned. Otherwise, the attribute is deleted.
  #
  # name  - the String attribute name
  #
  # returns true if the attribute was deleted, false if it was not because it's locked
  def delete_attribute(name)
    if attribute_locked?(name)
      false
    else
      @attributes.delete(name)
      @attributes_modified << name
      true
    end
  end

  # Public: Determine if the attribute has been locked by being assigned in document options
  #
  # key - The attribute key to check
  #
  # Returns true if the attribute is locked, false otherwise
  def attribute_locked?(name)
    @attribute_overrides.has_key?(name)
  end

  # Internal: Apply substitutions to the attribute value
  #
  # If the value is an inline passthrough macro (e.g., pass:<subs>[value]),
  # apply the substitutions defined in <subs> to the value, or leave the value
  # unmodified if no substitutions are specified.  If the value is not an
  # inline passthrough macro, apply header substitutions to the value.
  #
  # value - The String attribute value on which to perform substitutions
  #
  # Returns The String value with substitutions performed
  def apply_attribute_value_subs(value)
    if (m = AttributeEntryPassMacroRx.match(value))
      if !m[1].empty?
        subs = resolve_pass_subs m[1]
        subs.empty? ? m[2] : (apply_subs m[2], subs)
      else
        m[2]
      end
    else
      apply_header_subs value
    end
  end

  # Public: Update the backend attributes to reflect a change in the selected backend
  #
  # This method also handles updating the related doctype attributes if the
  # doctype attribute is assigned at the time this method is called.
  def update_backend_attributes new_backend, force = false
    if force || (new_backend && new_backend != @attributes['backend'])
      attrs = @attributes
      current_backend = attrs['backend']
      current_basebackend = attrs['basebackend']
      current_doctype = attrs['doctype']
      if new_backend.start_with? 'xhtml'
        attrs['htmlsyntax'] = 'xml'
        new_backend = new_backend[1..-1]
      elsif new_backend.start_with? 'html'
        attrs['htmlsyntax'] = 'html'
      end
      if (resolved_name = BACKEND_ALIASES[new_backend])
        new_backend = resolved_name
      end
      new_basebackend = new_backend.sub TrailingDigitsRx, ''
      if (page_width = DEFAULT_PAGE_WIDTHS[new_basebackend])
        attrs['pagewidth'] = page_width
      else
        attrs.delete 'pagewidth'
      end
      if current_backend
        attrs.delete %(backend-#{current_backend})
        if current_doctype
          attrs.delete %(backend-#{current_backend}-doctype-#{current_doctype})
        end
      end
      attrs['backend'] = new_backend
      attrs[%(backend-#{new_backend})] = ''
      if current_doctype
        attrs[%(doctype-#{current_doctype})] = ''
        attrs[%(backend-#{new_backend}-doctype-#{current_doctype})] = ''
      end
      if new_basebackend != current_basebackend
        if current_basebackend
          attrs.delete %(basebackend-#{current_basebackend})
          if current_doctype
            attrs.delete %(basebackend-#{current_basebackend}-doctype-#{current_doctype})
          end
        end
        attrs['basebackend'] = new_basebackend
        attrs[%(basebackend-#{new_basebackend})] = ''
        attrs[%(basebackend-#{new_basebackend}-doctype-#{current_doctype})] = '' if current_doctype
      end
      ext = DEFAULT_EXTENSIONS[new_basebackend] || '.html'
      new_file_type = ext[1..-1]
      current_file_type = attrs['filetype']
      attrs['outfilesuffix'] = ext unless attribute_locked? 'outfilesuffix'
      attrs.delete %(filetype-#{current_file_type}) if current_file_type
      attrs['filetype'] = new_file_type
      attrs[%(filetype-#{new_file_type})] = ''
      # clear cached value
      @backend = nil
      # (re)initialize converter
      @converter = create_converter
    end
  end

  def update_doctype_attributes new_doctype
    if new_doctype && new_doctype != @attributes['doctype']
      attrs = @attributes
      current_doctype = attrs['doctype']
      current_backend = attrs['backend']
      current_basebackend = attrs['basebackend']
      if current_doctype
        attrs.delete %(doctype-#{current_doctype})
        attrs.delete %(backend-#{current_backend}-doctype-#{current_doctype}) if current_backend
        attrs.delete %(basebackend-#{current_basebackend}-doctype-#{current_doctype}) if current_basebackend
      end
      attrs['doctype'] = new_doctype
      attrs[%(doctype-#{new_doctype})] = ''
      attrs[%(backend-#{current_backend}-doctype-#{new_doctype})] = '' if current_backend
      attrs[%(basebackend-#{current_basebackend}-doctype-#{new_doctype})] = '' if current_basebackend
      # clear cached value
      @doctype = nil
    end
  end

  def create_converter
    converter_opts = {}
    converter_opts[:htmlsyntax] = @attributes['htmlsyntax']
    template_dirs = if (template_dir = @options[:template_dir])
      converter_opts[:template_dirs] = [template_dir]
    elsif (template_dirs = @options[:template_dirs])
      converter_opts[:template_dirs] = template_dirs
    end
    if template_dirs
      converter_opts[:template_cache] = @options.fetch :template_cache, true
      converter_opts[:template_engine] = @options[:template_engine]
      converter_opts[:template_engine_options] = @options[:template_engine_options]
      converter_opts[:eruby] = @options[:eruby]
    end
    converter_factory = if (converter = @options[:converter])
      Converter::Factory.new Hash[backend, converter]
    else
      Converter::Factory.default false
    end
    # QUESTION should we honor the convert_opts?
    # QUESTION should we pass through all options and attributes too?
    #converter_opts.update opts
    converter_factory.create backend, converter_opts
  end

  # Public: Convert the AsciiDoc document using the templates
  # loaded by the Converter. If a :template_dir is not specified,
  # or a template is missing, the converter will fall back to
  # using the appropriate built-in template.
  def convert opts = {}
    restore_attributes

    # QUESTION should we add processors that execute before conversion begins?

    if doctype == 'inline'
      # QUESTION should we warn if @blocks.size > 0 and the first block is not a paragraph?
      if (block = @blocks[0]) && block.content_model != :compound
        output = block.content
      else
        output = ''
      end
    else
      transform = ((opts.key? :header_footer) ? opts[:header_footer] : @options[:header_footer]) ? 'document' : 'embedded'
      output = @converter.convert self, transform
    end

    if @extensions && !@parent_document
      if @extensions.postprocessors?
        @extensions.postprocessors.each do |ext|
          output = ext.process_method[self, output]
        end
      end
    end

    output
  end

  # Alias render to convert to maintain backwards compatibility
  alias :render :convert

  # Public: Write the output to the specified file
  #
  # If the converter responds to :write, delegate the work of writing the file
  # to that method. Otherwise, write the output the specified file.
  def write output, target
    if @converter.is_a? Writer
      @converter.write output, target
    else
      if target.respond_to? :write
        target.write output.chomp
        # ensure there's a trailing endline
        target.write EOL
      else
        ::File.open(target, 'w') {|f| f.write output }
      end
      nil
    end
  end

=begin
  def convert_to target, opts = {}
    start = ::Time.now.to_f if (monitor = opts[:monitor])
    output = (r = converter opts).convert
    monitor[:convert] = ::Time.now.to_f - start if monitor

    unless target.respond_to? :write
      @attributes['outfile'] = target = ::File.expand_path target
      @attributes['outdir'] = ::File.dirname target
    end

    start = ::Time.now.to_f if monitor
    r.write output, target
    monitor[:write] = ::Time.now.to_f - start if monitor 

    output
  end
=end

  def content
    # NOTE per AsciiDoc-spec, remove the title before converting the body
    @attributes.delete('title')
    super
  end

  # Public: Read the docinfo file(s) for inclusion in the
  # document template
  #
  # If the docinfo1 attribute is set, read the docinfo.ext file. If the docinfo
  # attribute is set, read the doc-name.docinfo.ext file. If the docinfo2
  # attribute is set, read both files in that order.
  #
  # pos - The Symbol position of the docinfo, either :header or :footer. (default: :header)
  # ext - The extension of the docinfo file(s). If not set, the extension
  #       will be determined based on the basebackend. (default: nil)
  #
  # returns The contents of the docinfo file(s)
  def docinfo(pos = :header, ext = nil)
    if safe >= SafeMode::SECURE
      ''
    else
      case pos
      when :footer
        qualifier = '-footer'
      else
        qualifier = nil
      end
      ext = @attributes['outfilesuffix'] if ext.nil?

      content = nil

      docinfo = @attributes.has_key?('docinfo')
      docinfo1 = @attributes.has_key?('docinfo1')
      docinfo2 = @attributes.has_key?('docinfo2')
      docinfo_filename = "docinfo#{qualifier}#{ext}"
      if docinfo1 || docinfo2
        docinfo_path = normalize_system_path(docinfo_filename)
        content = read_asset(docinfo_path)
        unless content.nil?
          # FIXME normalize these lines!
          content.force_encoding ::Encoding::UTF_8 if FORCE_ENCODING
          content = sub_attributes(content.split EOL) * EOL
        end
      end

      if (docinfo || docinfo2) && @attributes.has_key?('docname')
        docinfo_path = normalize_system_path("#{@attributes['docname']}-#{docinfo_filename}")
        content2 = read_asset(docinfo_path)
        unless content2.nil?
          # FIXME normalize these lines!
          content2.force_encoding ::Encoding::UTF_8 if FORCE_ENCODING
          content2 = sub_attributes(content2.split EOL) * EOL
          content = content.nil? ? content2 : "#{content}#{EOL}#{content2}"
        end
      end

      # to_s forces nil to empty string
      content.to_s
    end
  end

  def to_s
    %(#{self.class}@#{object_id} { doctype: #{doctype.inspect}, doctitle: #{(@header != nil ? @header.title : nil).inspect}, blocks: #{@blocks.size} })
  end

end
end
