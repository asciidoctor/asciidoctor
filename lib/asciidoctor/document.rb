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

  Footnote = ::Struct.new :index, :id, :text

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

  # Public Parsed and stores a partitioned title (i.e., title & subtitle).
  class Title
    attr_reader :main
    attr_reader :subtitle
    attr_reader :combined

    def initialize val, opts = {}
      # TODO separate sanitization by type (:cdata for HTML/XML, :plain for non-SGML, false for none)
      if (@sanitized = opts[:sanitize]) && val.include?('<')
        val = val.gsub(XmlSanitizeRx, '').tr_s(' ', ' ').strip
      end
      if (@combined = val).include? ': '
        @main, _, @subtitle = val.rpartition ': '
      else
        @main = val
        @subtitle = nil
      end
    end

    def sanitized?
      @sanitized
    end

    def subtitle?
      !!@subtitle
    end

    def to_s
      @combined
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

  # Public: Get the Boolean AsciiDoc compatibility mode
  #
  # enabling this attribute activates the following syntax changes:
  # 
  #   * single quotes as constrained emphasis formatting marks
  #   * single backticks parsed as inline literal, formatted as monospace
  #   * single plus parsed as constrained, monospaced inline formatting
  #   * double plus parsed as constrained, monospaced inline formatting
  #
  attr_reader :compat_mode

  # Public: Get the Boolean flag that indicates whether source map information is tracked by the parser
  attr_reader :sourcemap

  # Public: Get the Hash of document references
  attr_reader :references

  # Public: Get the Hash of document counters
  attr_reader :counters

  # Public: Get the Hash of callouts
  attr_reader :callouts

  # Public: Get the level-0 Section
  attr_reader :header

  # Public: Get the String base directory for converting this document.
  #
  # Defaults to directory of the source file.
  # If the source is a string, defaults to the current directory.
  attr_reader :base_dir

  # Public: Get a reference to the parent Document of this nested document.
  attr_reader :parent_document

  # Public: Get the Reader associated with this document
  attr_reader :reader

  # Public: Get the Converter associated with this document
  attr_reader :converter

  # Public: Get the extensions registry
  attr_reader :extensions

  # Public: Initialize a {Document} object.
  #
  # data    - The AsciiDoc source data as a String or String Array. (default: nil)
  # options - A Hash of options to control processing (e.g., safe mode value (:safe), backend (:backend),
  #           header/footer toggle (:header_footer), custom attributes (:attributes)). (default: {})
  #
  # Examples
  #
  #   data = File.read filename
  #   doc = Asciidoctor::Document.new data
  #   puts doc.convert
  def initialize data = nil, options = {}
    super self, :document

    if (parent_doc = options.delete :parent)
      @parent_document = parent_doc
      options[:base_dir] ||= parent_doc.base_dir
      @references = parent_doc.references.inject({}) do |accum, (key,ref)|
        if key == :footnotes
          accum[:footnotes] = []
        else
          accum[key] = ref
        end
        accum
      end
      # QUESTION should we support setting attribute in parent document from nested document?
      # NOTE we must dup or else all the assignments to the overrides clobbers the real attributes
      attr_overrides = parent_doc.attributes.dup
      attr_overrides.delete 'doctype'
      attr_overrides.delete 'compat-mode'
      @attribute_overrides = attr_overrides
      @safe = parent_doc.safe
      @compat_mode = parent_doc.compat_mode
      @sourcemap = parent_doc.sourcemap
      @converter = parent_doc.converter
      initialize_extensions = false
      @extensions = parent_doc.extensions
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
      attr_overrides = {}
      (options[:attributes] || {}).each do |key, value|
        if key.start_with? '!'
          key = key[1..-1]
          value = nil
        elsif key.end_with? '!'
          key = key.chop
          value = nil
        end
        attr_overrides[key.downcase] = value
      end
      @attribute_overrides = attr_overrides
      # safely resolve the safe mode from const, int or string
      if !(safe_mode = options[:safe])
        @safe = SafeMode::SECURE
      elsif ::Fixnum === safe_mode
        # be permissive in case API user wants to define new levels
        @safe = safe_mode
      else
        # NOTE: not using infix rescue for performance reasons, see https://github.com/jruby/jruby/issues/1816
        begin
          @safe = SafeMode.const_get(safe_mode.to_s.upcase)
        rescue
          @safe = SafeMode::SECURE
        end
      end
      @sourcemap = options[:sourcemap]
      @compat_mode = false
      @converter = nil
      initialize_extensions = defined? ::Asciidoctor::Extensions
      @extensions = nil # initialize furthur down
    end

    @parsed = false
    @header = nil
    @counters = {}
    @callouts = Callouts.new
    @attributes_modified = ::Set.new
    @options = options
    header_footer = (options[:header_footer] ||= false)

    attrs = @attributes
    attrs['encoding'] = 'UTF-8'
    attrs['sectids'] = ''
    attrs['notitle'] = '' unless header_footer
    attrs['toc-placement'] = 'auto'
    attrs['stylesheet'] = ''
    attrs['webfonts'] = ''
    attrs['copycss'] = '' if header_footer
    attrs['prewrap'] = ''
    attrs['attribute-undefined'] = Compliance.attribute_undefined
    attrs['attribute-missing'] = Compliance.attribute_missing
    attrs['iconfont-remote'] = ''

    # language strings
    # TODO load these based on language settings
    attrs['caution-caption'] = 'Caution'
    attrs['important-caption'] = 'Important'
    attrs['note-caption'] = 'Note'
    attrs['tip-caption'] = 'Tip'
    attrs['warning-caption'] = 'Warning'
    attrs['appendix-caption'] = 'Appendix'
    attrs['example-caption'] = 'Example'
    attrs['figure-caption'] = 'Figure'
    #attrs['listing-caption'] = 'Listing'
    attrs['table-caption'] = 'Table'
    attrs['toc-title'] = 'Table of Contents'
    attrs['manname-title'] = 'NAME'
    attrs['untitled-label'] = 'Untitled'
    attrs['version-label'] = 'Version'
    attrs['last-update-label'] = 'Last updated'

    attr_overrides['asciidoctor'] = ''
    attr_overrides['asciidoctor-version'] = VERSION

    safe_mode_name = SafeMode.constants.detect {|l| SafeMode.const_get(l) == @safe }.to_s.downcase
    attr_overrides['safe-mode-name'] = safe_mode_name
    attr_overrides["safe-mode-#{safe_mode_name}"] = ''
    attr_overrides['safe-mode-level'] = @safe

    # sync the embedded attribute w/ the value of options...do not allow override
    attr_overrides['embedded'] = header_footer ? nil : ''

    # the only way to set the max-include-depth attribute is via the document options
    # 64 is the AsciiDoc default
    attr_overrides['max-include-depth'] ||= 64

    # the only way to enable uri reads is via the document options, disabled by default
    unless !attr_overrides['allow-uri-read'].nil?
      attr_overrides['allow-uri-read'] = nil
    end

    attr_overrides['user-home'] = USER_HOME

    # legacy support for numbered attribute
    attr_overrides['sectnums'] = attr_overrides.delete 'numbered' if attr_overrides.key? 'numbered'

    # if the base_dir option is specified, it overrides docdir as the root for relative paths
    # otherwise, the base_dir is the directory of the source file (docdir) or the current
    # directory of the input is a string
    if options[:base_dir]
      @base_dir = attr_overrides['docdir'] = ::File.expand_path(options[:base_dir])
    else
      if attr_overrides['docdir']
        @base_dir = attr_overrides['docdir'] = ::File.expand_path(attr_overrides['docdir'])
      else
        #warn 'asciidoctor: WARNING: setting base_dir is recommended when working with string documents' unless nested?
        @base_dir = attr_overrides['docdir'] = ::File.expand_path(::Dir.pwd)
      end
    end

    # allow common attributes backend and doctype to be set using options hash, coerce values to string
    if (backend_val = options[:backend])
      attr_overrides['backend'] = %(#{backend_val})
    end

    if (doctype_val = options[:doctype])
      attr_overrides['doctype'] = %(#{doctype_val})
    end

    if @safe >= SafeMode::SERVER
      # restrict document from setting copycss, source-highlighter and backend
      attr_overrides['copycss'] ||= nil
      attr_overrides['source-highlighter'] ||= nil
      attr_overrides['backend'] ||= DEFAULT_BACKEND
      # restrict document from seeing the docdir and trim docfile to relative path
      if !parent_doc && attr_overrides.key?('docfile')
        attr_overrides['docfile'] = attr_overrides['docfile'][(attr_overrides['docdir'].length + 1)..-1]
      end
      attr_overrides['docdir'] = ''
      attr_overrides['user-home'] = '.'
      if @safe >= SafeMode::SECURE
        # assign linkcss (preventing css embedding) unless explicitly disabled from the commandline or API
        # effectively the same has "has key 'linkcss' and value == nil"
        unless attr_overrides.fetch('linkcss', '').nil?
          attr_overrides['linkcss'] = ''
        end
        # restrict document from enabling icons
        attr_overrides['icons'] ||= nil
      end
    end
    
    attr_overrides.delete_if do |key, val|
      verdict = false
      # a nil value undefines the attribute 
      if val.nil?
        attrs.delete(key)
      else
        # a value ending in @ indicates this attribute does not override
        # an attribute with the same key in the document souce
        if (val.is_a? ::String) && (val.end_with? '@')
          val = val.chop
          verdict = true
        end
        attrs[key] = val
      end
      verdict
    end

    @compat_mode = true if attrs.key? 'compat-mode'

    if parent_doc
      # setup default doctype (backend is fixed)
      attrs['doctype'] ||= DEFAULT_DOCTYPE

      # don't need to do the extra processing within our own document
      # FIXME line info isn't reported correctly within include files in nested document
      @reader = Reader.new data, options[:cursor]

      # Now parse the lines in the reader into blocks
      # Eagerly parse (for now) since a subdocument is not a publicly accessible object
      Parser.parse @reader, self

      # should we call rewind in some sort of post-parse function?
      @callouts.rewind
      @parsed = true
    else
      # setup default backend and doctype
      attrs['backend'] ||= DEFAULT_BACKEND
      attrs['doctype'] ||= DEFAULT_DOCTYPE
      update_backend_attributes attrs['backend'], true

      #attrs['indir'] = attrs['docdir']
      #attrs['infile'] = attrs['docfile']

      # dynamic intrinstic attribute values
      now = ::Time.now
      localdate = (attrs['localdate'] ||= now.strftime('%Y-%m-%d'))
      unless (localtime = attrs['localtime'])
        begin
          localtime = attrs['localtime'] = now.strftime('%H:%M:%S %Z')
        rescue
          localtime = attrs['localtime'] = now.strftime('%H:%M:%S')
        end
      end
      attrs['localdatetime'] ||= %(#{localdate} #{localtime})

      # docdate, doctime and docdatetime should default to
      # localdate, localtime and localdatetime if not otherwise set
      attrs['docdate'] ||= localdate
      attrs['doctime'] ||= localtime
      attrs['docdatetime'] ||= %(#{localdate} #{localtime})

      # fallback directories
      attrs['stylesdir'] ||= '.'
      attrs['iconsdir'] ||= ::File.join(attrs.fetch('imagesdir', './images'), 'icons')

      @extensions = if initialize_extensions
        registry = if (ext_registry = options[:extensions_registry])
          if (ext_registry.is_a? Extensions::Registry) ||
              (::RUBY_ENGINE_JRUBY && (ext_registry.is_a? ::AsciidoctorJ::Extensions::ExtensionRegistry))
            ext_registry
          end
        elsif (ext_block = options[:extensions]).is_a? ::Proc
          Extensions.build_registry(&ext_block)
        end
        (registry ||= Extensions::Registry.new).activate self
      end

      @reader = PreprocessorReader.new self, data, Reader::Cursor.new(attrs['docfile'], @base_dir)
    end
  end

  # Public: Parse the AsciiDoc source stored in the {Reader} into an abstract syntax tree.
  #
  # If the data parameter is not nil, create a new {PreprocessorReader} and assigned it to the reader
  # property of this object. Otherwise, continue with the reader that was created in {#initialize}. 
  # Pass the reader to {Parser.parse} to parse the source data into an abstract syntax tree.
  #
  # If parsing has already been performed, this method returns without performing any processing.
  #
  # data - The optional replacement AsciiDoc source data as a String or String Array. (default: nil)
  #
  # Returns this [Document]
  def parse data = nil
    if @parsed
      self
    else
      doc = self
      # create reader if data is provided (used when data is not known at the time the Document object is created)
      @reader = PreprocessorReader.new doc, data, Reader::Cursor.new(@attributes['docfile'], @base_dir) if data

      if (exts = @parent_document ? nil : @extensions) && exts.preprocessors?
        exts.preprocessors.each do |ext|
          @reader = ext.process_method[doc, @reader] || @reader
        end
      end

      # Now parse the lines in the reader into blocks
      Parser.parse @reader, doc, :header_only => !!@options[:parse_header_only]

      # should we call rewind in some sort of post-parse function?
      @callouts.rewind

      if exts && exts.treeprocessors?
        exts.treeprocessors.each do |ext|
          if (result = ext.process_method[doc]) && Document === result && result != doc
            doc = result
          end
        end
      end

      @parsed = true
      doc
    end
  end

  # Public: Get the named counter and take the next number in the sequence.
  #
  # name  - the String name of the counter
  # seed  - the initial value as a String or Integer
  #
  # returns the next number in the sequence for the specified counter
  def counter(name, seed = nil)
    if (attr_is_seed = !(attr_val = @attributes[name]).nil_or_empty?) && @counters.key?(name)
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
    !@references[:footnotes].empty?
  end

  def footnotes
    @references[:footnotes]
  end

  def nested?
    !!@parent_document
  end

  def embedded?
    # QUESTION should this be !@options[:header_footer] ?
    @attributes.key? 'embedded'
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

  # Public: Resolves the primary title for the document
  #
  # Searches the locations to find the first non-empty
  # value:
  #
  #  * document-level attribute named title
  #  * header title (known as the document title)
  #  * title of the first section
  #  * document-level attribute named untitled-label (if :use_fallback option is set)
  #
  # If no value can be resolved, nil is returned.
  #
  # If the :partition attribute is specified, the value is parsed into an Document::Title object.
  # If the :sanitize attribute is specified, XML elements are removed from the value.
  #
  # Returns the resolved title as a [Title] if the :partition option is passed or a [String] if not
  # or nil if no value can be resolved.
  def doctitle opts = {}
    if !(val = @attributes['title'].nil_or_empty?)
      val = title
    elsif (sect = first_section) && sect.title?
      val = sect.title
    elsif opts[:use_fallback] && (val = @attributes['untitled-label'])
      # use val set in condition
    else
      return
    end
    
    if opts[:partition]
      Title.new val, opts
    elsif opts[:sanitize] && val.include?('<')
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
    !@attributes.key?('showtitle') && @attributes.key?('notitle')
  end

  def noheader
    @attributes.key? 'noheader'
  end

  def nofooter
    @attributes.key? 'nofooter'
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
    # enable toc and sectnums (i.e., numbered) by default in DocBook backend
    # NOTE the attributes_modified should go away once we have a proper attribute storage & tracking facility
    if (attrs = @attributes)['basebackend'] == 'docbook'
      attrs['toc'] = '' unless attribute_locked?('toc') || @attributes_modified.include?('toc')
      attrs['sectnums'] = '' unless attribute_locked?('sectnums') || @attributes_modified.include?('sectnums')
    end

    unless attrs.key?('doctitle') || !(val = doctitle)
      attrs['doctitle'] = val
    end

    # css-signature cannot be updated after header attributes are processed
    @id = attrs['css-signature'] unless @id

    toc_position_val = if (toc_val = (attrs.delete('toc2') ? 'left' : attrs['toc']))
      # toc-placement allows us to separate position from using fitted slot vs macro
      (toc_placement = attrs.fetch('toc-placement', 'macro')) && toc_placement != 'auto' ? toc_placement : attrs['toc-position']
    else
      nil
    end

    if toc_val && (!toc_val.empty? || !toc_position_val.nil_or_empty?)
      default_toc_position = 'left'
      # TODO rename toc2 to aside-toc
      default_toc_class = 'toc2'
      if !toc_position_val.nil_or_empty?
        position = toc_position_val
      elsif !toc_val.empty?
        position = toc_val
      else
        position = default_toc_position
      end
      attrs['toc'] = ''
      attrs['toc-placement'] = 'auto'
      case position
      when 'left', '<', '&lt;'
        attrs['toc-position'] = 'left'
      when 'right', '>', '&gt;'
        attrs['toc-position'] = 'right'
      when 'top', '^'
        attrs['toc-position'] = 'top'
      when 'bottom', 'v'
        attrs['toc-position'] = 'bottom'
      when 'preamble', 'macro'
        attrs['toc-position'] = 'content'
        attrs['toc-placement'] = position
        default_toc_class = nil
      else
        attrs.delete 'toc-position'
        default_toc_class = nil
      end
      attrs['toc-class'] ||= default_toc_class if default_toc_class
    end

    if attrs.key? 'compat-mode'
      attrs['source-language'] = attrs['language'] if attrs.has_key? 'language'
      @compat_mode = true
    else
      @compat_mode = false
    end

    @original_attributes = attrs.dup

    # unfreeze "flexible" attributes
    unless nested?
      FLEXIBLE_ATTRIBUTES.each do |name|
        # turning a flexible attribute off should be permanent
        # (we may need more config if that's not always the case)
        if @attribute_overrides.key?(name) && @attribute_overrides[name]
          @attribute_overrides.delete(name)
        end
      end
    end
  end

  # Internal: Restore the attributes to the previously saved state
  #--
  # QUESTION should we restore attributes after parse?
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
    if block_attributes.key? :attribute_entries
      block_attributes[:attribute_entries].each do |entry|
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
    @attribute_overrides.key?(name)
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
      if current_backend
        attrs.delete %(backend-#{current_backend})
        if current_doctype
          attrs.delete %(backend-#{current_backend}-doctype-#{current_doctype})
        end
      end
      if current_doctype
        attrs[%(doctype-#{current_doctype})] = ''
        attrs[%(backend-#{new_backend}-doctype-#{current_doctype})] = ''
      end
      attrs['backend'] = new_backend
      attrs[%(backend-#{new_backend})] = ''
      # (re)initialize converter
      if (@converter = create_converter).is_a? Converter::BackendInfo
        new_basebackend = @converter.basebackend
        attrs['outfilesuffix'] = @converter.outfilesuffix unless attribute_locked? 'outfilesuffix'
        new_filetype = @converter.filetype
      else
        new_basebackend = new_backend.sub TrailingDigitsRx, ''
        # QUESTION should we be forcing the basebackend to html if unknown?
        new_outfilesuffix = DEFAULT_EXTENSIONS[new_basebackend] || '.html'
        new_filetype = new_outfilesuffix[1..-1]
        attrs['outfilesuffix'] = new_outfilesuffix unless attribute_locked? 'outfilesuffix'
      end
      if (current_filetype = attrs['filetype'])
        attrs.delete %(filetype-#{current_filetype})
      end
      attrs['filetype'] = new_filetype
      attrs[%(filetype-#{new_filetype})] = ''
      if (page_width = DEFAULT_PAGE_WIDTHS[new_basebackend])
        attrs['pagewidth'] = page_width
      else
        attrs.delete 'pagewidth'
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
      # clear cached backend value
      @backend = nil
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
      # clear cached doctype value
      @doctype = nil
    end
  end

  # TODO document me
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
      Converter::Factory.new ::Hash[backend, converter]
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
    parse unless @parsed
    restore_attributes

    # QUESTION should we add processors that execute before conversion begins?
    unless @converter
      fail %(asciidoctor: FAILED: missing converter for backend '#{backend}'. Processing aborted.)
    end

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

    unless @parent_document
      if (exts = @extensions) && exts.postprocessors?
        exts.postprocessors.each do |ext|
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

      docinfo = @attributes.key?('docinfo')
      docinfo1 = @attributes.key?('docinfo1')
      docinfo2 = @attributes.key?('docinfo2')
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

      if (docinfo || docinfo2) && @attributes.key?('docname')
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
    %(#<#{self.class}@#{object_id} {doctype: #{doctype.inspect}, doctitle: #{(@header != nil ? @header.title : nil).inspect}, blocks: #{@blocks.size}}>)
  end

end
end
