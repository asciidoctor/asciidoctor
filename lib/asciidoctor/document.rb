# frozen_string_literal: true
module Asciidoctor
# Public: The Document class represents a parsed AsciiDoc document.
#
# Document is the root node of a parsed AsciiDoc document. It provides an
# abstract syntax tree (AST) that represents the structure of the AsciiDoc
# document from which the Document object was parsed.
#
# Although the constructor can be used to create an empty document object, more
# commonly, you'll load the document object from AsciiDoc source using the
# primary API methods, {Asciidoctor.load} or {Asciidoctor.load_file}. When
# using one of these APIs, you almost always want to set the safe mode to
# :safe (or :unsafe) to enable all of Asciidoctor's features.
#
#   Asciidoctor.load '= Hello, AsciiDoc!', safe: :safe
#   # => Asciidoctor::Document { doctype: "article", doctitle: "Hello, AsciiDoc!", blocks: 0 }
#
# Instances of this class can be used to extract information from the document
# or alter its structure. As such, the Document object is most often used in
# extensions and by integrations.
#
# The most basic usage of the Document object is to retrieve the document's
# title.
#
#   source = '= Document Title'
#   document = Asciidoctor.load source, safe: :safe
#   document.doctitle
#   # => 'Document Title'
#
# If the document has no title, the {Document#doctitle} method returns the
# title of the first section. If that check falls through, you can have the
# method return a fallback value (the value of the untitled-label attribute).
#
#   Asciidoctor.load('no doctitle', safe: :safe).doctitle use_fallback: true
#   # => "Untitled"
#
# You can also use the Document object to access document attributes defined in
# the header, such as the author and doctype.
#
#   source = '= Document Title
#   Author Name
#   :doctype: book'
#   document = Asciidoctor.load source, safe: :safe
#   document.author
#   # => 'Author Name'
#   document.doctype
#   # => 'book'
#
# You can retrieve arbitrary document attributes defined in the header using
# {Document#attr} or check for the existence of one using {Document#attr?}:
#
#   source = '= Asciidoctor
#   :uri-project: https://asciidoctor.org'
#   document = Asciidoctor.load source, safe: :safe
#   document.attr 'uri-project'
#   # => 'https://asciidoctor.org'
#   document.attr? 'icons'
#   # => false
#
# Starting at the Document object, you can begin walking the document tree using
# the {Document#blocks} method:
#
#   source = 'paragraph contents
#
#   [sidebar]
#   sidebar contents'
#   doc = Asciidoctor.load source, safe: :safe
#   doc.blocks.map {|block| block.context }
#   # => [:paragraph, :sidebar]
#
# You can discover block nodes at any depth in the tree using the
# {AbstractBlock#find_by} method.
#
#   source = '****
#   paragraph in sidebar
#   ****'
#   doc = Asciidoctor.load source, safe: :safe
#   doc.find_by(context: :paragraph).map {|block| block.context }
#   # => [:paragraph]
#
# Loading a document object is the first step in the conversion process. You
# can take the process to completion by calling the {Document#convert} method.
class Document < AbstractBlock

  ImageReference = ::Struct.new :target, :imagesdir do
    alias to_s target
  end

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
      self
    end
  end

  # Public Parsed and stores a partitioned title (i.e., title & subtitle).
  class Title
    attr_reader :main
    alias title main
    attr_reader :subtitle
    attr_reader :combined

    def initialize val, opts = {}
      # TODO separate sanitization by type (:cdata for HTML/XML, :plain_text for non-SGML, false for none)
      if (@sanitized = opts[:sanitize]) && val.include?('<')
        val = val.gsub(XmlSanitizeRx, '').squeeze(' ').strip
      end
      if (sep = opts[:separator] || ':').empty? || !val.include?(sep = %(#{sep} ))
        @main = val
        @subtitle = nil
      else
        @main, _, @subtitle = val.rpartition sep
      end
      @combined = val
    end

    def sanitized?
      @sanitized
    end

    def subtitle?
      @subtitle ? true : false
    end

    def to_s
      @combined
    end
  end

  # Public: The Author class represents information about an author extracted from document attributes
  Author = ::Struct.new :name, :firstname, :middlename, :lastname, :initials, :email

  # Public A read-only integer value indicating the level of security that
  # should be enforced while processing this document. The value must be
  # set in the Document constructor using the :safe option.
  #
  # A value of 0 (UNSAFE) disables any of the security features enforced
  # by Asciidoctor (Ruby is still subject to its own restrictions).
  #
  # A value of 1 (SAFE) closely parallels safe mode in AsciiDoc. In particular,
  # it prevents access to files which reside outside of the parent directory
  # of the source file and disables any macro other than the include directive.
  #
  # A value of 10 (SERVER) disallows the document from setting attributes that
  # would affect the conversion of the document, in addition to all the security
  # features of SafeMode::SAFE. For instance, this level forbids changing the
  # backend or source-highlighter using an attribute defined in the source
  # document header. This is the most fundamental level of security for server
  # deployments (hence the name).
  #
  # A value of 20 (SECURE) disallows the document from attempting to read files
  # from the file system and including the contents of them into the document,
  # in addition to all the security features of SafeMode::SECURE. In
  # particular, it disallows use of the include::[] directive and the embedding of
  # binary content (data uri), stylesheets and JavaScripts referenced by the
  # document. (Asciidoctor and trusted extensions may still be allowed to embed
  # trusted content into the document).
  #
  # Since Asciidoctor is aiming for wide adoption, 20 (SECURE) is the default
  # value and is recommended for server deployments.
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

  # Public: Get the cached value of the backend attribute for this document
  attr_reader :backend

  # Public: Get the cached value of the doctype attribute for this document
  attr_reader :doctype

  # Public: Get or set the Boolean flag that indicates whether source map information should be tracked by the parser
  attr_accessor :sourcemap

  # Public: Get the document catalog Hash
  attr_reader :catalog

  # Public: Alias catalog property as references for backwards compatibility
  alias references catalog

  # Public: Get the Hash of document counters
  attr_reader :counters

  # Public: Get the level-0 Section (i.e., doctitle). (Only stores the title, not the header attributes).
  attr_reader :header

  # Public: Get the String base directory for converting this document.
  #
  # Defaults to directory of the source file.
  # If the source is a string, defaults to the current directory.
  attr_reader :base_dir

  # Public: Get the Hash of resolved options used to initialize this Document
  attr_reader :options

  # Public: Get the outfilesuffix defined at the end of the header.
  attr_reader :outfilesuffix

  # Public: Get a reference to the parent Document of this nested document.
  attr_reader :parent_document

  # Public: Get the Reader associated with this document
  attr_reader :reader

  # Public: Get/Set the PathResolver instance used to resolve paths in this Document.
  attr_reader :path_resolver

  # Public: Get the Converter associated with this document
  attr_reader :converter

  # Public: Get the SyntaxHighlighter associated with this document
  attr_reader :syntax_highlighter

  # Public: Get the activated Extensions::Registry associated with this document.
  attr_reader :extensions

  # Public: Initialize a {Document} object.
  #
  # data    - The AsciiDoc source data as a String or String Array. (default: nil)
  # options - A Hash of options to control processing (e.g., safe mode value (:safe), backend (:backend),
  #           standalone enclosure (:standalone), custom attributes (:attributes)). (default: {})
  #
  # Duplication of the options Hash is handled in the enclosing API.
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
      options[:catalog_assets] = true if parent_doc.options[:catalog_assets]
      options[:to_dir] = parent_doc.options[:to_dir] if parent_doc.options[:to_dir]
      @catalog = parent_doc.catalog.merge footnotes: []
      # QUESTION should we support setting attribute in parent document from nested document?
      @attribute_overrides = attr_overrides = (parent_doc.instance_variable_get :@attribute_overrides).merge parent_doc.attributes
      attr_overrides.delete 'compat-mode'
      parent_doctype = attr_overrides.delete 'doctype'
      attr_overrides.delete 'notitle'
      attr_overrides.delete 'showtitle'
      # QUESTION if toc is hard unset in parent document, should it be hard unset in nested document?
      attr_overrides.delete 'toc'
      @attributes['toc-placement'] = (attr_overrides.delete 'toc-placement') || 'auto'
      attr_overrides.delete 'toc-position'
      @safe = parent_doc.safe
      @attributes['compat-mode'] = '' if (@compat_mode = parent_doc.compat_mode)
      @outfilesuffix = parent_doc.outfilesuffix
      @sourcemap = parent_doc.sourcemap
      @timings = nil
      @path_resolver = parent_doc.path_resolver
      @converter = parent_doc.converter
      initialize_extensions = nil
      @extensions = parent_doc.extensions
      @syntax_highlighter = parent_doc.syntax_highlighter
    else
      @parent_document = nil
      @catalog = {
        ids: {}, # deprecated; kept for backwards compatibility with converters
        refs: {},
        footnotes: [],
        links: [],
        images: [],
        callouts: Callouts.new,
        includes: {},
      }
      # copy attributes map and normalize keys
      # attribute overrides are attributes that can only be set from the commandline
      # a direct assignment effectively makes the attribute a constant
      # a nil value or name with leading or trailing ! will result in the attribute being unassigned
      @attribute_overrides = attr_overrides = {}
      (options[:attributes] || {}).each do |key, val|
        if key.end_with? '@'
          if key.start_with? '!'
            key, val = (key.slice 1, key.length - 2), false
          elsif key.end_with? '!@'
            key, val = (key.slice 0, key.length - 2), false
          else
            key, val = key.chop, %(#{val}@)
          end
        elsif key.start_with? '!'
          key, val = (key.slice 1, key.length), val == '@' ? false : nil
        elsif key.end_with? '!'
          key, val = key.chop, val == '@' ? false : nil
        end
        attr_overrides[key.downcase] = val
      end
      if ::String === (to_file = options[:to_file])
        attr_overrides['outfilesuffix'] = Helpers.extname to_file
      end
      # safely resolve the safe mode from const, int or string
      if !(safe_mode = options[:safe])
        @safe = SafeMode::SECURE
      elsif ::Integer === safe_mode
        # be permissive in case API user wants to define new levels
        @safe = safe_mode
      else
        @safe = (SafeMode.value_for_name safe_mode) rescue SafeMode::SECURE
      end
      input_mtime = options.delete :input_mtime
      @compat_mode = attr_overrides.key? 'compat-mode'
      @sourcemap = options[:sourcemap]
      @timings = options.delete :timings
      @path_resolver = PathResolver.new
      initialize_extensions = (defined? ::Asciidoctor::Extensions) || (options.key? :extensions) ? ::Asciidoctor::Extensions : nil
      @extensions = nil # initialize further down if initialize_extensions is true
      options[:standalone] = options[:header_footer] if (options.key? :header_footer) && !(options.key? :standalone)
    end

    @parsed = @reftexts = @header = @header_attributes = nil
    @counters = {}
    @attributes_modified = ::Set.new
    @docinfo_processor_extensions = {}
    standalone = options[:standalone]
    (@options = options).freeze

    attrs = @attributes
    unless parent_doc
      attrs['attribute-undefined'] = Compliance.attribute_undefined
      attrs['attribute-missing'] = Compliance.attribute_missing
      attrs.update DEFAULT_ATTRIBUTES
      # TODO if lang attribute is set, @safe mode < SafeMode::SERVER, and !parent_doc,
      # load attributes from data/locale/attributes-<lang>.adoc
    end

    if standalone
      # sync embedded attribute with :standalone option value
      attr_overrides['embedded'] = nil
      attrs['copycss'] = ''
      attrs['iconfont-remote'] = ''
      attrs['stylesheet'] = ''
      attrs['webfonts'] = ''
    else
      # sync embedded attribute with :standalone option value
      attr_overrides['embedded'] = ''
      if (attr_overrides.key? 'showtitle') && (attr_overrides.keys & %w(notitle showtitle))[-1] == 'showtitle'
        attr_overrides['notitle'] = { nil => '', false => '@', '@' => false }[attr_overrides['showtitle']]
      elsif attr_overrides.key? 'notitle'
        attr_overrides['showtitle'] = { nil => '', false => '@', '@' => false }[attr_overrides['notitle']]
      else
        attrs['notitle'] = ''
      end
    end

    attr_overrides['asciidoctor'] = ''
    attr_overrides['asciidoctor-version'] = ::Asciidoctor::VERSION

    attr_overrides['safe-mode-name'] = (safe_mode_name = SafeMode.name_for_value @safe)
    attr_overrides[%(safe-mode-#{safe_mode_name})] = ''
    attr_overrides['safe-mode-level'] = @safe

    # the only way to set the max-include-depth attribute is via the API; default to 64 like AsciiDoc.py
    attr_overrides['max-include-depth'] ||= 64

    # the only way to set the allow-uri-read attribute is via the API; disabled by default
    attr_overrides['allow-uri-read'] ||= nil

    # remap legacy attribute names
    attr_overrides['sectnums'] = attr_overrides.delete 'numbered' if attr_overrides.key? 'numbered'
    attr_overrides['hardbreaks-option'] = attr_overrides.delete 'hardbreaks' if attr_overrides.key? 'hardbreaks'

    # If the base_dir option is specified, it overrides docdir and is used as the root for relative
    # paths. Otherwise, the base_dir is the directory of the source file (docdir), if set, otherwise
    # the current directory.
    if (base_dir_val = options[:base_dir])
      @base_dir = (attr_overrides['docdir'] = ::File.expand_path base_dir_val)
    elsif attr_overrides['docdir']
      @base_dir = attr_overrides['docdir']
    else
      #logger.warn 'setting base_dir is recommended when working with string documents' unless nested?
      @base_dir = attr_overrides['docdir'] = ::Dir.pwd
    end

    # allow common attributes backend and doctype to be set using options hash, coerce values to string
    if (backend_val = options[:backend])
      attr_overrides['backend'] = backend_val.to_s
    end

    if (doctype_val = options[:doctype])
      attr_overrides['doctype'] = doctype_val.to_s
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
      attr_overrides['user-home'] ||= '.'
      if @safe >= SafeMode::SECURE
        attr_overrides['max-attribute-value-size'] = 4096 unless attr_overrides.key? 'max-attribute-value-size'
        # assign linkcss (preventing css embedding) unless explicitly disabled from the commandline or API
        #attr_overrides['linkcss'] = (attr_overrides.fetch 'linkcss', '') || nil
        attr_overrides['linkcss'] = '' unless attr_overrides.key? 'linkcss'
        # restrict document from enabling icons
        attr_overrides['icons'] ||= nil
      end
    else
      attr_overrides['user-home'] ||= USER_HOME
    end

    # the only way to set the max-attribute-value-size attribute is via the API; disabled by default
    @max_attribute_value_size = (size = (attr_overrides['max-attribute-value-size'] ||= nil)) ? size.to_i.abs : nil

    attr_overrides.delete_if do |key, val|
      if val
        # a value ending in @ allows document to override value
        if ::String === val && (val.end_with? '@')
          val, verdict = val.chop, true
        end
        attrs[key] = val
      else
        # a nil or false value both unset the attribute; only a nil value locks it
        attrs.delete key
        verdict = val == false
      end
      verdict
    end

    if parent_doc
      @backend = attrs['backend']
      # reset doctype unless it matches the default value
      unless (@doctype = attrs['doctype'] = parent_doctype) == DEFAULT_DOCTYPE
        update_doctype_attributes DEFAULT_DOCTYPE
      end

      # don't need to do the extra processing within our own document
      # FIXME line info isn't reported correctly within include files in nested document
      @reader = Reader.new data, options[:cursor]
      @source_location = @reader.cursor if @sourcemap

      # Now parse the lines in the reader into blocks
      # Eagerly parse (for now) since a subdocument is not a publicly accessible object
      Parser.parse @reader, self

      # should we call some sort of post-parse function?
      restore_attributes
      @parsed = true
    else
      # setup default backend and doctype
      @backend = nil
      if (initial_backend = attrs['backend'] || DEFAULT_BACKEND) == 'manpage'
        @doctype = attrs['doctype'] = attr_overrides['doctype'] = 'manpage'
      else
        @doctype = (attrs['doctype'] ||= DEFAULT_DOCTYPE)
      end
      update_backend_attributes initial_backend, true

      # dynamic intrinstic attribute values

      #attrs['indir'] = attrs['docdir']
      #attrs['infile'] = attrs['docfile']

      # fallback directories
      attrs['stylesdir'] ||= '.'
      attrs['iconsdir'] ||= %(#{attrs.fetch 'imagesdir', './images'}/icons)

      fill_datetime_attributes attrs, input_mtime

      if initialize_extensions
        if (ext_registry = options[:extension_registry])
          # QUESTION should we warn if the value type of this option is not a registry
          if Extensions::Registry === ext_registry || ((defined? ::AsciidoctorJ::Extensions::ExtensionRegistry) &&
              ::AsciidoctorJ::Extensions::ExtensionRegistry === ext_registry)
            @extensions = ext_registry.activate self
          end
        elsif (ext_block = options[:extensions]).nil?
          @extensions = Extensions::Registry.new.activate self unless Extensions.groups.empty?
        elsif ::Proc === ext_block
          @extensions = Extensions.create(&ext_block).activate self
        end
      end

      @reader = PreprocessorReader.new self, data, (Reader::Cursor.new attrs['docfile'], @base_dir), normalize: true
      @source_location = @reader.cursor if @sourcemap
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
      if data
        @reader = PreprocessorReader.new doc, data, (Reader::Cursor.new @attributes['docfile'], @base_dir), normalize: true
        @source_location = @reader.cursor if @sourcemap
      end

      if (exts = @parent_document ? nil : @extensions) && exts.preprocessors?
        exts.preprocessors.each do |ext|
          @reader = ext.process_method[doc, @reader] || @reader
        end
      end

      # Now parse the lines in the reader into blocks
      Parser.parse @reader, doc, header_only: @options[:parse_header_only]

      # should we call sort of post-parse function?
      restore_attributes

      if exts && exts.tree_processors?
        exts.tree_processors.each do |ext|
          if (result = ext.process_method[doc]) && Document === result && result != doc
            doc = result
          end
        end
      end

      @parsed = true
      doc
    end
  end

  # Public: Returns whether the source lines of the document have been parsed.
  def parsed?
    @parsed
  end

  # Public: Get the named counter and take the next number in the sequence.
  #
  # name  - the String name of the counter
  # seed  - the initial value as a String or Integer
  #
  # returns the next number in the sequence for the specified counter
  def counter name, seed = nil
    return @parent_document.counter name, seed if @parent_document
    if ((locked = attribute_locked? name) && (curr_val = @counters[name])) || !(curr_val = @attributes[name]).nil_or_empty?
      next_val = @counters[name] = Helpers.nextval curr_val
    elsif seed
      next_val = @counters[name] = seed == seed.to_i.to_s ? seed.to_i : seed
    else
      next_val = @counters[name] = 1
    end
    @attributes[name] = next_val unless locked
    next_val
  end

  # Public: Increment the specified counter and store it in the block's attributes
  #
  # counter_name - the String name of the counter attribute
  # block        - the Block on which to save the counter
  #
  # returns the next number in the sequence for the specified counter
  def increment_and_store_counter counter_name, block
    ((AttributeEntry.new counter_name, (counter counter_name)).save_to block.attributes).value
  end
  # Deprecated: Map old counter_increment method to increment_counter for backwards compatibility
  alias counter_increment increment_and_store_counter

  # Public: Register a reference in the document catalog
  def register type, value
    case type
    when :ids # deprecated
      register :refs, [(id = value[0]), (Inline.new self, :anchor, value[1], type: :ref, id: id)]
    when :refs
      @catalog[:refs][value[0]] ||= (ref = value[1])
      ref
    when :footnotes
      @catalog[type] << value
    else
      @catalog[type] << (type == :images ? (ImageReference.new value, @attributes['imagesdir']) : value) if @options[:catalog_assets]
    end
  end

  # Public: Scan registered references and return the ID of the first reference that matches the specified reference text.
  #
  # text - The String reference text to compare to the converted reference text of each registered reference.
  #
  # Returns the String ID of the first reference with matching reference text or nothing if no reference is found.
  def resolve_id text
    if @reftexts
      @reftexts[text]
    elsif @parsed
      # @reftexts is set eagerly to prevent nested lazy init
      (@reftexts = {}).tap {|accum| @catalog[:refs].each {|id, ref| accum[ref.xreftext] ||= id } }[text]
    else
      resolved_id = nil
      # @reftexts is set eagerly to prevent nested lazy init
      @reftexts = accum = {}
      @catalog[:refs].each do |id, ref|
        # NOTE short-circuit early since we're throwing away this table anyway
        if (xreftext = ref.xreftext) == text
          resolved_id = id
          break
        end
        accum[xreftext] ||= id
      end
      @reftexts = nil
      resolved_id
    end
  end

  # Public: Check whether this Document has any child Section objects.
  #
  # Returns A [Boolean] to indicate whether this Document has child Section objects
  def sections?
    @next_section_index > 0
  end

  def footnotes?
    @catalog[:footnotes].empty? ? false : true
  end

  def footnotes
    @catalog[:footnotes]
  end

  def callouts
    @catalog[:callouts]
  end

  def nested?
    @parent_document ? true : false
  end

  def embedded?
    @attributes.key? 'embedded'
  end

  def extensions?
    @extensions ? true : false
  end

  # Make the raw source for the Document available.
  def source
    @reader.source if @reader
  end

  # Make the raw source lines for the Document available.
  def source_lines
    @reader.source_lines if @reader
  end

  def basebackend? base
    @attributes['basebackend'] == base
  end

  # Public: Return the doctitle as a String
  #
  # Returns the resolved doctitle as a [String] or nil if a doctitle cannot be resolved
  def title
    doctitle
  end

  # Public: Set the title on the document header
  #
  # Set the title of the document header to the specified value. If the header
  # does not exist, it is first created.
  #
  # title - the String title to assign as the title of the document header
  #
  # Returns the specified [String] title
  def title= title
    unless (sect = @header)
      (sect = (@header = Section.new self, 0)).sectname = 'header'
    end
    sect.title = title
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
  # TODO separate sanitization by type (:cdata for HTML/XML, :plain_text for non-SGML, false for none)
  #
  # Returns the resolved title as a [Title] if the :partition option is passed or a [String] if not
  # or nil if no value can be resolved.
  def doctitle opts = {}
    unless (val = @attributes['title'])
      if (sect = first_section)
        val = sect.title
      elsif !(opts[:use_fallback] && (val = @attributes['untitled-label']))
        return
      end
    end

    if (separator = opts[:partition])
      Title.new val, opts.merge({ separator: (separator == true ? @attributes['title-separator'] : separator) })
    elsif opts[:sanitize] && val.include?('<')
      val.gsub(XmlSanitizeRx, '').squeeze(' ').strip
    else
      val
    end
  end
  alias name doctitle

  def xreftext xrefstyle = nil
    (val = reftext) && !val.empty? ? val : title
  end

  # Public: Convenience method to retrieve the document attribute 'author'
  #
  # returns the full name of the author as a String
  def author
    @attributes['author']
  end

  # Public: Convenience method to retrieve the authors of this document as an Array of Author objects.
  #
  # This method is backed by the author-related attributes on the document.
  #
  # returns the authors of this document as an Array
  def authors
    if (attrs = @attributes).key? 'author'
      authors = [(Author.new attrs['author'], attrs['firstname'], attrs['middlename'], attrs['lastname'], attrs['authorinitials'], attrs['email'])]
      if (num_authors = attrs['authorcount'] || 0) > 1
        idx = 1
        while idx < num_authors
          idx += 1
          authors << (Author.new attrs[%(author_#{idx})], attrs[%(firstname_#{idx})], attrs[%(middlename_#{idx})], attrs[%(lastname_#{idx})], attrs[%(authorinitials_#{idx})], attrs[%(email_#{idx})])
        end
      end
      authors
    else
      []
    end
  end

  # Public: Convenience method to retrieve the document attribute 'revdate'
  #
  # returns the date of last revision for the document as a String
  def revdate
    @attributes['revdate']
  end

  def notitle
    @attributes.key? 'notitle'
  end

  def noheader
    @attributes.key? 'noheader'
  end

  def nofooter
    @attributes.key? 'nofooter'
  end

  def first_section
    @header || @blocks.find {|e| e.context == :section }
  end

  def header?
    @header ? true : false
  end
  alias has_header? header?

  # Public: Append a content Block to this Document.
  #
  # If the child block is a Section, assign an index to it.
  #
  # block - The child Block to append to this parent Block
  #
  # Returns The parent Block
  def << block
    assign_numeral block if block.context == :section
    super
  end

  # Internal: Called by the parser after parsing the header and before parsing
  # the body, even if no header is found.
  #--
  # QUESTION should we invoke the TreeProcessors here, passing in a phase?
  # QUESTION is finalize_header the right name?
  def finalize_header unrooted_attributes, header_valid = true
    clear_playback_attributes unrooted_attributes
    save_attributes
    unrooted_attributes['invalid-header'] = true unless header_valid
    unrooted_attributes
  end

  # Public: Replay attribute assignments at the block level
  def playback_attributes(block_attributes)
    if block_attributes.key? :attribute_entries
      block_attributes[:attribute_entries].each do |entry|
        name = entry.name
        if entry.negate
          @attributes.delete name
          @compat_mode = false if name == 'compat-mode'
        else
          @attributes[name] = entry.value
          @compat_mode = true if name == 'compat-mode'
        end
      end
    end
  end

  # Public: Restore the attributes to the previously saved state (attributes in header)
  def restore_attributes
    @catalog[:callouts].rewind unless @parent_document
    @attributes.replace @header_attributes
  end

  # Public: Set the specified attribute on the document if the name is not locked
  #
  # If the attribute is locked, false is returned. Otherwise, the value is
  # assigned to the attribute name after first performing attribute
  # substitutions on the value. If the attribute name is 'backend' or
  # 'doctype', then the value of backend-related attributes are updated.
  #
  # name  - the String attribute name
  # value - the String attribute value; must not be nil (optional, default: '')
  #
  # Returns the substituted value if the attribute was set or nil if it was not because it's locked.
  def set_attribute name, value = ''
    unless attribute_locked? name
      value = apply_attribute_value_subs value unless value.empty?
      # NOTE if @header_attributes is set, we're beyond the document header
      if @header_attributes
        @attributes[name] = value
      else
        case name
        when 'backend'
          update_backend_attributes value, (@attributes_modified.delete? 'htmlsyntax') && value == @backend
        when 'doctype'
          update_doctype_attributes value
        else
          @attributes[name] = value
        end
        @attributes_modified << name
      end
      value
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

  # Public: Assign a value to the specified attribute in the document header.
  #
  # The assignment will be visible when the header attributes are restored,
  # typically between processor phases (e.g., between parse and convert).
  #
  # name      - The String attribute name to assign
  # value     - The Object value to assign to the attribute (default: '')
  # overwrite - A Boolean indicating whether to assign the attribute
  #             if already present in the attributes Hash (default: true)
  #
  # Returns a [Boolean] indicating whether the assignment was performed
  def set_header_attribute name, value = '', overwrite = true
    attrs = @header_attributes || @attributes
    if overwrite == false && (attrs.key? name)
      false
    else
      attrs[name] = value
      true
    end
  end

  # Public: Convert the AsciiDoc document using the templates
  # loaded by the Converter. If a :template_dir is not specified,
  # or a template is missing, the converter will fall back to
  # using the appropriate built-in template.
  def convert opts = {}
    @timings.start :convert if @timings
    parse unless @parsed
    unless @safe >= SafeMode::SERVER || opts.empty?
      # QUESTION should we store these on the Document object?
      @attributes.delete 'outfile' unless (@attributes['outfile'] = opts['outfile'])
      @attributes.delete 'outdir' unless (@attributes['outdir'] = opts['outdir'])
    end

    # QUESTION should we add extensions that execute before conversion begins?

    if doctype == 'inline'
      if (block = @blocks[0] || @header)
        if block.content_model == :compound || block.content_model == :empty
          logger.warn 'no inline candidate; use the inline doctype to convert a single paragragh, verbatim, or raw block'
        else
          output = block.content
        end
      end
    else
      if opts.key? :standalone
        transform = opts[:standalone] ? 'document' : 'embedded'
      elsif opts.key? :header_footer
        transform = opts[:header_footer] ? 'document' : 'embedded'
      else
        transform = @options[:standalone] ? 'document' : 'embedded'
      end
      output = @converter.convert self, transform
    end

    unless @parent_document
      if (exts = @extensions) && exts.postprocessors?
        exts.postprocessors.each do |ext|
          output = ext.process_method[self, output]
        end
      end
    end

    @timings.record :convert if @timings
    output
  end

  # Deprecated: Use {Document#convert} instead.
  alias render convert

  # Public: Write the output to the specified file
  #
  # If the converter responds to :write, delegate the work of writing the output
  # to that method. Otherwise, write the output to the specified file. In the
  # latter case, this method ensures the output has a trailing newline if the
  # target responds to write and the output is not empty.
  #
  # output - The output to write. Unless the converter responds to write, this
  #          object is expected to be a String.
  # target - The file to write, either a File object or a String path.
  #
  # Returns nothing
  def write output, target
    @timings.start :write if @timings
    if Writer === @converter
      @converter.write output, target
    else
      if target.respond_to? :write
        # QUESTION should we set encoding using target.set_encoding?
        unless output.nil_or_empty?
          target.write output.chomp
          # ensure there's a trailing endline
          target.write LF
        end
      else
        ::File.write target, output, mode: FILE_WRITE_MODE
      end
      if @backend == 'manpage' && ::String === target && (@converter.class.respond_to? :write_alternate_pages)
        @converter.class.write_alternate_pages @attributes['mannames'], @attributes['manvolnum'], target
      end
    end
    @timings.record :write if @timings
    nil
  end

  def content
    # NOTE per AsciiDoc-spec, remove the title before converting the body
    @attributes.delete('title')
    super
  end

  # Public: Read the docinfo file(s) for inclusion in the document template
  #
  # If the docinfo1 attribute is set, read the docinfo.ext file. If the docinfo
  # attribute is set, read the doc-name.docinfo.ext file. If the docinfo2
  # attribute is set, read both files in that order.
  #
  # location - The Symbol location of the docinfo (e.g., :head, :footer, etc). (default: :head)
  # suffix   - The suffix of the docinfo file(s). If not set, the extension
  #            will be set to the outfilesuffix. (default: nil)
  #
  # returns The contents of the docinfo file(s) or empty string if no files are
  # found or the safe mode is secure or greater.
  def docinfo location = :head, suffix = nil
    if safe < SafeMode::SECURE
      qualifier = %(-#{location}) unless location == :head
      suffix ||= @outfilesuffix

      if (docinfo = @attributes['docinfo']).nil_or_empty?
        if @attributes.key? 'docinfo2'
          docinfo = ['private', 'shared']
        elsif @attributes.key? 'docinfo1'
          docinfo = ['shared']
        else
          docinfo = docinfo ? ['private'] : nil
        end
      else
        docinfo = docinfo.split(',').map {|it| it.strip }
      end

      if docinfo
        content = []
        docinfo_file, docinfo_dir, docinfo_subs = %(docinfo#{qualifier}#{suffix}), @attributes['docinfodir'], resolve_docinfo_subs
        unless (docinfo & ['shared', %(shared-#{location})]).empty?
          docinfo_path = normalize_system_path docinfo_file, docinfo_dir
          # NOTE normalizing the lines is essential if we're performing substitutions
          if (shared_docinfo = read_asset docinfo_path, normalize: true)
            content << (apply_subs shared_docinfo, docinfo_subs)
          end
        end

        unless @attributes['docname'].nil_or_empty? || (docinfo & ['private', %(private-#{location})]).empty?
          docinfo_path = normalize_system_path %(#{@attributes['docname']}-#{docinfo_file}), docinfo_dir
          # NOTE normalizing the lines is essential if we're performing substitutions
          if (private_docinfo = read_asset docinfo_path, normalize: true)
            content << (apply_subs private_docinfo, docinfo_subs)
          end
        end
      end
    end

    # TODO allow document to control whether extension docinfo is contributed
    if @extensions && (docinfo_processors? location)
      ((content || []).concat @docinfo_processor_extensions[location].map {|ext| ext.process_method[self] }.compact).join LF
    elsif content
      content.join LF
    else
      ''
    end
  end

  def docinfo_processors?(location = :head)
    if @docinfo_processor_extensions.key?(location)
      # false means we already performed a lookup and didn't find any
      @docinfo_processor_extensions[location] != false
    elsif @extensions && @document.extensions.docinfo_processors?(location)
      !!(@docinfo_processor_extensions[location] = @document.extensions.docinfo_processors(location))
    else
      @docinfo_processor_extensions[location] = false
    end
  end

  def to_s
    %(#<#{self.class}@#{object_id} {doctype: #{doctype.inspect}, doctitle: #{(@header && @header.title).inspect}, blocks: #{@blocks.size}}>)
  end

  private

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
  def apply_attribute_value_subs value
    if AttributeEntryPassMacroRx =~ value
      value = $2
      value = apply_subs value, (resolve_pass_subs $1) if $1
    else
      value = apply_header_subs value
    end
    @max_attribute_value_size ? (limit_bytesize value, @max_attribute_value_size) : value
  end

  # Internal: Safely truncates a string to the specified number of bytes.
  #
  # If a multibyte char gets split, the dangling fragment is dropped.
  #
  # str - The String the truncate.
  # max - The maximum allowable size of the String, in bytes.
  #
  # Returns the String truncated to the specified bytesize.
  def limit_bytesize str, max
    if str.bytesize > max
      max -= 1 until (str = str.byteslice 0, max).valid_encoding?
    end
    str
  end

  # Internal: Resolve the list of comma-delimited subs to apply to docinfo files.
  #
  # Resolve the list of substitutions from the value of the docinfosubs
  # document attribute, if specified. Otherwise, return an Array containing
  # the Symbol :attributes.
  #
  # Returns an [Array] of substitution [Symbol]s
  def resolve_docinfo_subs
    (@attributes.key? 'docinfosubs') ? (resolve_subs @attributes['docinfosubs'], :block, nil, 'docinfo') : [:attributes]
  end

  # Internal: Create and initialize an instance of the converter for this document
  #--
  # QUESTION is there any additional information we should be passing to the converter?
  def create_converter backend, delegate_backend
    converter_opts = { document: self, htmlsyntax: @attributes['htmlsyntax'] }
    if (template_dirs = (opts = @options)[:template_dirs] || opts[:template_dir])
      converter_opts[:template_dirs] = [*template_dirs]
      converter_opts[:template_cache] = opts.fetch :template_cache, true
      converter_opts[:template_engine] = opts[:template_engine]
      converter_opts[:template_engine_options] = opts[:template_engine_options]
      converter_opts[:eruby] = opts[:eruby]
      converter_opts[:safe] = @safe
      converter_opts[:delegate_backend] = delegate_backend if delegate_backend
    end
    if (converter = opts[:converter])
      (Converter::CustomFactory.new backend => converter).create backend, converter_opts
    else
      (opts.fetch :converter_factory, Converter).create backend, converter_opts
    end
  end

  # Internal: Delete any attributes stored for playback
  def clear_playback_attributes(attributes)
    attributes.delete(:attribute_entries)
  end

  # Internal: Branch the attributes so that the original state can be restored
  # at a future time.
  #
  # Returns the duplicated attributes, which will later be restored
  def save_attributes
    unless ((attrs = @attributes).key? 'doctitle') || !(doctitle_val = doctitle)
      attrs['doctitle'] = doctitle_val
    end

    # css-signature cannot be updated after header attributes are processed
    @id ||= attrs['css-signature']

    if (toc_val = (attrs.delete 'toc2') ? 'left' : attrs['toc'])
      # toc-placement allows us to separate position from using fitted slot vs macro
      toc_position_val = (toc_placement_val = attrs.fetch 'toc-placement', 'macro') && toc_placement_val != 'auto' ? toc_placement_val : attrs['toc-position']
      unless toc_val.empty? && toc_position_val.nil_or_empty?
        default_toc_position = 'left'
        # TODO rename toc2 to aside-toc
        default_toc_class = 'toc2'
        position = toc_position_val.nil_or_empty? ? (toc_val.empty? ? default_toc_position : toc_val) : toc_position_val
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
    end

    if (icons_val = attrs['icons']) && !(attrs.key? 'icontype')
      case icons_val
      when '', 'font'
      else
        attrs['icons'] = ''
        attrs['icontype'] = icons_val unless icons_val == 'image'
      end
    end

    if (@compat_mode = attrs.key? 'compat-mode') && (attrs.key? 'language')
      attrs['source-language'] = attrs['language']
    end

    unless @parent_document
      if (basebackend = attrs['basebackend']) == 'html'
        # QUESTION should we allow source-highlighter to be disabled in AsciiDoc table cell?
        if (syntax_hl_name = attrs['source-highlighter']) && !attrs[%(#{syntax_hl_name}-unavailable)]
          if (syntax_hl_factory = @options[:syntax_highlighter_factory])
            @syntax_highlighter = syntax_hl_factory.create syntax_hl_name, @backend, document: self
          elsif (syntax_hls = @options[:syntax_highlighters])
            @syntax_highlighter = (SyntaxHighlighter::DefaultFactoryProxy.new syntax_hls).create syntax_hl_name, @backend, document: self
          else
            @syntax_highlighter = SyntaxHighlighter.create syntax_hl_name, @backend, document: self
          end
        end
      # enable toc and sectnums (i.e., numbered) by default in DocBook backend
      elsif basebackend == 'docbook'
        # NOTE the attributes_modified should go away once we have a proper attribute storage & tracking facility
        attrs['toc'] = '' unless (attribute_locked? 'toc') || (@attributes_modified.include? 'toc')
        attrs['sectnums'] = '' unless (attribute_locked? 'sectnums') || (@attributes_modified.include? 'sectnums')
      end

      # NOTE pin the outfilesuffix after the header is parsed
      @outfilesuffix = attrs['outfilesuffix']

      # unfreeze "flexible" attributes
      FLEXIBLE_ATTRIBUTES.each do |name|
        # turning a flexible attribute off should be permanent
        # (we may need more config if that's not always the case)
        if @attribute_overrides.key?(name) && @attribute_overrides[name]
          @attribute_overrides.delete(name)
        end
      end
    end

    @header_attributes = attrs.merge
  end

  # Internal: Assign the local and document datetime attributes, which includes localdate, localyear, localtime,
  # localdatetime, docdate, docyear, doctime, and docdatetime. Honor the SOURCE_DATE_EPOCH environment variable, if set.
  def fill_datetime_attributes attrs, input_mtime
    # See https://reproducible-builds.org/specs/source-date-epoch/
    now = (::ENV.key? 'SOURCE_DATE_EPOCH') ? (source_date_epoch = (::Time.at Integer ::ENV['SOURCE_DATE_EPOCH']).utc) : ::Time.now
    if (localdate = attrs['localdate'])
      attrs['localyear'] ||= (localdate.index '-') == 4 ? (localdate.slice 0, 4) : nil
    else
      localdate = attrs['localdate'] = now.strftime '%F'
      attrs['localyear'] ||= now.year.to_s
    end
    # %Z is OS dependent and may contain characters that aren't UTF-8 encoded (see asciidoctor#2770 and asciidoctor.js#23)
    localtime = (attrs['localtime'] ||= now.strftime %(%T #{now.utc_offset == 0 ? 'UTC' : '%z'}))
    attrs['localdatetime'] ||= %(#{localdate} #{localtime})
    # docdate, doctime and docdatetime should default to localdate, localtime and localdatetime if not otherwise set
    input_mtime = source_date_epoch || input_mtime || now
    if (docdate = attrs['docdate'])
      attrs['docyear'] ||= ((docdate.index '-') == 4 ? (docdate.slice 0, 4) : nil)
    else
      docdate = attrs['docdate'] = input_mtime.strftime '%F'
      attrs['docyear'] ||= input_mtime.year.to_s
    end
    # %Z is OS dependent and may contain characters that aren't UTF-8 encoded (see asciidoctor#2770 and asciidoctor.js#23)
    doctime = (attrs['doctime'] ||= input_mtime.strftime %(%T #{input_mtime.utc_offset == 0 ? 'UTC' : '%z'}))
    attrs['docdatetime'] ||= %(#{docdate} #{doctime})
    nil
  end

  # Internal: Update the backend attributes to reflect a change in the active backend.
  #
  # This method also handles updating the related doctype attributes if the
  # doctype attribute is assigned at the time this method is called.
  #
  # Returns the resolved String backend if updated, nothing otherwise.
  def update_backend_attributes new_backend, init = nil
    if init || new_backend != @backend
      current_backend = @backend
      current_basebackend = (attrs = @attributes)['basebackend']
      current_doctype = @doctype
      actual_backend, _, new_backend = new_backend.partition ':' if new_backend.include? ':'
      if new_backend.start_with? 'xhtml'
        attrs['htmlsyntax'] = 'xml'
        new_backend = new_backend.slice 1, new_backend.length
      elsif new_backend.start_with? 'html'
        attrs['htmlsyntax'] ||= 'html'
      end
      new_backend = BACKEND_ALIASES[new_backend] || new_backend
      new_backend, delegate_backend = actual_backend, new_backend if actual_backend
      if current_doctype
        if current_backend
          attrs.delete %(backend-#{current_backend})
          attrs.delete %(backend-#{current_backend}-doctype-#{current_doctype})
        end
        attrs[%(backend-#{new_backend}-doctype-#{current_doctype})] = ''
        attrs[%(doctype-#{current_doctype})] = ''
      elsif current_backend
        attrs.delete %(backend-#{current_backend})
      end
      attrs[%(backend-#{new_backend})] = ''
      # QUESTION should we defer the @backend assignment until after the converter is created?
      @backend = attrs['backend'] = new_backend
      # (re)initialize converter
      if Converter::BackendTraits === (converter = create_converter new_backend, delegate_backend)
        new_basebackend = converter.basebackend
        new_filetype = converter.filetype
        if (htmlsyntax = converter.htmlsyntax)
          attrs['htmlsyntax'] = htmlsyntax
        end
        if init
          attrs['outfilesuffix'] ||= converter.outfilesuffix
        else
          attrs['outfilesuffix'] = converter.outfilesuffix unless attribute_locked? 'outfilesuffix'
        end
      elsif converter
        backend_traits = Converter.derive_backend_traits new_backend
        new_basebackend = backend_traits[:basebackend]
        new_filetype = backend_traits[:filetype]
        if init
          attrs['outfilesuffix'] ||= backend_traits[:outfilesuffix]
        else
          attrs['outfilesuffix'] = backend_traits[:outfilesuffix] unless attribute_locked? 'outfilesuffix'
        end
      else
        # NOTE ideally we shouldn't need the converter before the converter phase, but we do
        raise ::NotImplementedError, %(asciidoctor: FAILED: missing converter for backend '#{new_backend}'. Processing aborted.)
      end
      @converter = converter
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
        if current_doctype
          if current_basebackend
            attrs.delete %(basebackend-#{current_basebackend})
            attrs.delete %(basebackend-#{current_basebackend}-doctype-#{current_doctype})
          end
          attrs[%(basebackend-#{new_basebackend}-doctype-#{current_doctype})] = ''
        elsif current_basebackend
          attrs.delete %(basebackend-#{current_basebackend})
        end
        attrs[%(basebackend-#{new_basebackend})] = ''
        attrs['basebackend'] = new_basebackend
      end
      new_backend
    end
  end

  # Internal: Update the doctype and backend attributes to reflect a change in the active doctype.
  #
  # Returns the String doctype if updated, nothing otherwise.
  def update_doctype_attributes new_doctype
    if new_doctype && new_doctype != @doctype
      current_backend, current_basebackend, current_doctype = @backend, (attrs = @attributes)['basebackend'], @doctype
      if current_doctype
        attrs.delete %(doctype-#{current_doctype})
        if current_backend
          attrs.delete %(backend-#{current_backend}-doctype-#{current_doctype})
          attrs[%(backend-#{current_backend}-doctype-#{new_doctype})] = ''
        end
        if current_basebackend
          attrs.delete %(basebackend-#{current_basebackend}-doctype-#{current_doctype})
          attrs[%(basebackend-#{current_basebackend}-doctype-#{new_doctype})] = ''
        end
      else
        attrs[%(backend-#{current_backend}-doctype-#{new_doctype})] = '' if current_backend
        attrs[%(basebackend-#{current_basebackend}-doctype-#{new_doctype})] = '' if current_basebackend
      end
      attrs[%(doctype-#{new_doctype})] = ''
      @doctype = attrs['doctype'] = new_doctype
    end
  end
end
end
