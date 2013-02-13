# Public: Methods for parsing Asciidoc documents and rendering them
# using erb templates.
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
class Asciidoctor::Document < Asciidoctor::AbstractBlock

  include Asciidoctor

  Footnote = Struct.new(:index, :id, :text)
  AttributeEntry = Struct.new(:name, :value, :negate) do
    def initialize(name, value, negate = nil)
      super(name, value, negate.nil? ? value.nil? : false)
    end

    def save_to(block_attributes)
      block_attributes[:attribute_entries] ||= []
      block_attributes[:attribute_entries] << self
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
  # would affect the rendering of the document, in addition to all the security
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

  # Public: Base directory for rendering this document. Defaults to directory of the source file.
  # If the source is a string, defaults to the current directory.
  attr_reader :base_dir

  # Public: A reference to the parent document of this nested document.
  attr_reader :parent_document

  # Public: Initialize an Asciidoc object.
  #
  # data    - The Array of Strings holding the Asciidoc source document. (default: [])
  # options - A Hash of options to control processing, such as setting the safe mode (:safe),
  #           suppressing the header/footer (:header_footer) and attribute overrides (:attributes)
  #           (default: {})
  # block   - A block that can be used to retrieve external Asciidoc
  #           data to include in this document.
  #
  # Examples
  #
  #   data = File.readlines(filename)
  #   doc  = Asciidoctor::Document.new(data)
  #   puts doc.render
  def initialize(data = [], options = {}, &block)
    super(self, :document)
    @renderer = nil

    if options[:parent]
      @parent_document = options.delete(:parent)
      # should we dup here?
      options[:attributes] = @parent_document.attributes
      options[:safe] ||= @parent_document.safe
      options[:base_dir] ||= @parent_document.base_dir
      @renderer = @parent_document.renderer
    else
      @parent_document = nil
    end

    @header = nil
    @references = {
      :ids => {},
      :footnotes => [],
      :links => [],
      :images => [],
      :indexterms => []
    }
    @counters = {}
    @callouts = Callouts.new
    @options = options
    @safe = @options.fetch(:safe, SafeMode::SECURE).to_i
    @options[:header_footer] = @options.fetch(:header_footer, false)

    @attributes['asciidoctor'] = ''
    @attributes['asciidoctor-version'] = VERSION
    @attributes['sectids'] = ''
    @attributes['encoding'] = 'UTF-8'

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
    @attributes['table-caption'] = 'Table'
    @attributes['toc-title'] = 'Table of Contents'

    @attribute_overrides = options[:attributes] || {}

    # the only way to set the include-depth attribute is via the document options
    # 10 is the AsciiDoc default, though currently Asciidoctor only supports 1 level
    @attribute_overrides['include-depth'] ||= 10

    # if the base_dir option is specified, it overrides docdir as the root for relative paths
    # otherwise, the base_dir is the directory of the source file (docdir) or the current
    # directory of the input is a string
    if options[:base_dir].nil?
      if @attribute_overrides['docdir']
        @base_dir = @attribute_overrides['docdir'] = File.expand_path(@attribute_overrides['docdir'])
      else
        # perhaps issue a warning here?
        @base_dir = @attribute_overrides['docdir'] = Dir.pwd
      end
    else
      @base_dir = @attribute_overrides['docdir'] = File.expand_path(options[:base_dir])
    end

    if @safe >= SafeMode::SERVER
      # restrict document from setting source-highlighter and backend
      @attribute_overrides['source-highlighter'] ||= nil
      @attribute_overrides['backend'] ||= DEFAULT_BACKEND
      # restrict document from seeing the docdir and trim docfile to relative path
      if @attribute_overrides.has_key?('docfile') && @parent_document.nil?
        @attribute_overrides['docfile'] = @attribute_overrides['docfile'][(@attribute_overrides['docdir'].length + 1)..-1]
      end
      @attribute_overrides['docdir'] = ''
      # restrict document from enabling icons
      if @safe >= SafeMode::SECURE
        @attribute_overrides['icons'] ||= nil
      end
    end
    
    @attribute_overrides.delete_if {|key, val|
      verdict = false
      # a nil or negative key undefines the attribute 
      if val.nil? || key[-1..-1] == '!'
        @attributes.delete(key.chomp '!')
      # otherwise it's an attribute assignment
      else
        # a value ending in @ indicates this attribute does not override
        # an attribute with the same key in the document souce
        if val.is_a?(String) && val.end_with?('@')
          val.chop!
          verdict = true
        end
        @attributes[key] = val
      end
      verdict
    }

    @attributes['backend'] ||= DEFAULT_BACKEND
    @attributes['doctype'] ||= DEFAULT_DOCTYPE
    update_backend_attributes

    if !@parent_document.nil?
      # don't need to do the extra processing within our own document
      @reader = Reader.new(data)
    else
      @reader = Reader.new(data, self, true, &block)
    end

    # dynamic intrinstic attribute values
    now = Time.new
    @attributes['localdate'] ||= now.strftime('%Y-%m-%d')
    @attributes['localtime'] ||= now.strftime('%H:%M:%S %Z')
    @attributes['localdatetime'] ||= [@attributes['localdate'], @attributes['localtime']] * ' '
    
    # docdate, doctime and docdatetime should default to
    # localdate, localtime and localdatetime if not otherwise set
    @attributes['docdate'] ||= @attributes['localdate']
    @attributes['doctime'] ||= @attributes['localtime']
    @attributes['docdatetime'] ||= @attributes['localdatetime']
    
    @attributes['iconsdir'] ||= File.join(@attributes.fetch('imagesdir', 'images'), 'icons')

    # Now parse the lines in the reader into blocks
    Lexer.parse(@reader, self, :header_only => @options.fetch(:parse_header_only, false)) 

    @callouts.rewind

    Asciidoctor.debug {
      msg = []
      msg << "Found #{@blocks.size} blocks in this document:"
      @blocks.each {|b|
        msg << b
      }
      msg * "\n"
    }
  end

  # Public: Get the named counter and take the next number in the sequence.
  #
  # name  - the String name of the counter
  # seed  - the initial value as a String or Integer
  #
  # returns the next number in the sequence for the specified counter
  def counter(name, seed = nil)
    if !@counters.has_key? name
      if seed.nil?
        seed = nextval(@attributes.has_key?(name) ? @attributes[name] : 0)
      elsif seed.to_i.to_s == seed
        seed = seed.to_i
      end
      @counters[name] = seed
    else
      @counters[name] = nextval(@counters[name])
    end

    (@attributes[name] = @counters[name])
  end

  # Internal: Get the next value in the sequence.
  #
  # Handles both integer and character sequences.
  #
  # current - the value to increment as a String or Integer
  #
  # returns the next value in the sequence according to the current value's type
  def nextval(current)
    if current.is_a?(Integer)
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
      if value.is_a?(Array)
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

  def nested?
    !@parent_document.nil?
  end

  # Make the raw source for the Document available.
  def source
    @reader.source.join if @reader
  end

  # Make the raw source lines for the Document available.
  def source_lines
    @reader.source if @reader
  end

  def doctype
    @attributes['doctype']
  end

  # The title explicitly defined in the document attributes
  def title
    @attributes['title']
  end

  def title=(title)
    @header = Section.new self
    @header.title = title
  end

  # We need to be able to return some semblance of a title
  def doctitle
    if !(title = @attributes.fetch('title', '')).empty?
      title
    elsif !(sect = first_section).nil? && sect.title?
      sect.title
    else
      nil
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
    @attributes.has_key? 'notitle'
  end

  def noheader
    @attributes.has_key? 'noheader'
  end

  # QUESTION move to AbstractBlock?
  def first_section
    has_header? ? @header : (@blocks || []).detect{|e| e.is_a? Section}
  end

  def has_header?
    !@header.nil?
  end
 
  # Internal: Branch the attributes so that the original state can be restored
  # at a future time.
  def save_attributes
    # css-signature cannot be updated after header attributes are processed
    if @id.nil? && @attributes.has_key?('css-signature')
      @id = @attributes['css-signature']
    end
    @original_attributes = @attributes.dup
  end

  # Internal: Restore the attributes to the previously saved state
  def restore_attributes
    @attributes = @original_attributes
  end

  # Internal: Delete any attributes stored for playback
  def clear_playback_attributes(attributes)
    attributes.delete(:attribute_entries)
  end

  # Internal: Replay attribute assignments at the block level
  def playback_attributes(block_attributes)
    if block_attributes.has_key? :attribute_entries
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
      @attributes[name] = apply_attribute_value_subs(value)
      if name == 'backend'
        update_backend_attributes()
      end
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
      true
    end
  end

  # Public: Determine if the attribute has been locked by being assigned in document options
  #
  # key - The attribute key to check
  #
  # Returns true if the attribute is locked, false otherwise
  def attribute_locked?(name)
    @attribute_overrides.has_key?(name) || @attribute_overrides.has_key?("#{name}!")
  end

  # Internal: Apply substitutions to the attribute value
  #
  # If the value is an inline passthrough macro (e.g., pass:[text]), then
  # apply the substitutions defined on the macro to the text. Otherwise,
  # apply the verbatim substitutions to the value.
  #
  # value - The String attribute value on which to perform substitutions
  #
  # Returns The String value with substitutions performed.
  def apply_attribute_value_subs(value)
    if value.match(REGEXP[:pass_macro_basic])
      # copy match for Ruby 1.8.7 compat
      m = $~
      subs = []
      if !m[1].empty?
        subs = resolve_subs(m[1])
      end
      if !subs.empty?
        apply_subs(m[2], subs)
      else
        m[2]
      end
    else
      apply_header_subs(value)
    end
  end

  # Public: Update the backend attributes to reflect a change in the selected backend
  def update_backend_attributes()
    backend = @attributes['backend']
    if BACKEND_ALIASES.has_key? backend
      backend = @attributes['backend'] = BACKEND_ALIASES[backend]
    end
    basebackend = backend.sub(/[[:digit:]]+$/, '')
    page_width = DEFAULT_PAGE_WIDTHS[basebackend]
    if page_width
      @attributes['pagewidth'] = page_width
    else
      @attributes.delete('pagewidth')
    end
    @attributes["backend-#{backend}"] = ''
    @attributes['basebackend'] = basebackend
    @attributes["basebackend-#{basebackend}"] = ''
    # REVIEW cases for the next two assignments
    @attributes["#{backend}-#{@attributes['doctype']}"] = ''
    @attributes["#{basebackend}-#{@attributes['doctype']}"] = ''
    ext = DEFAULT_EXTENSIONS[basebackend] || '.html'
    @attributes['outfilesuffix'] = ext
    file_type = ext[1..-1]
    @attributes['filetype'] = file_type
    @attributes["filetype-#{file_type}"] = ''
  end

  def splain
    Asciidoctor.debug {
      msg = ''
      if @header
        msg = "Header is #{@header}"
      else
        msg = "No header"
      end

      msg += "I have #{@blocks.count} blocks"
      @blocks.each_with_index do |block, i|
        msg += "v" * 60
        msg += "Block ##{i} is a #{block.class}"
        msg += "Name is #{block.title rescue 'n/a'}"
        block.splain(0) if block.respond_to? :splain
        msg += "^" * 60
      end
    }
    nil
  end

  def renderer(opts = {})
    return @renderer if @renderer
    
    render_options = {}

    # Load up relevant Document @options
    if @options[:template_dir]
      render_options[:template_dir] = @options[:template_dir]
    end
    
    render_options[:backend] = @attributes.fetch('backend', 'html5')
    render_options[:eruby] = @options.fetch(:eruby, 'erb')
    render_options[:compact] = @options.fetch(:compact, false)
    
    # Override Document @option settings with options passed in
    render_options.merge! opts

    @renderer = Renderer.new(render_options)
  end

  # Public: Render the Asciidoc document using the templates
  # loaded by Renderer. If a :template_dir is not specified,
  # or a template is missing, the renderer will fall back to
  # using the appropriate built-in template.
  def render(opts = {})
    restore_attributes
    r = renderer(opts)
    @options.merge(opts)[:header_footer] ? r.render('document', self).strip : r.render('embedded', self)
  end

  def content
    # per AsciiDoc-spec, remove the title after rendering the header
    @attributes.delete('title')
    @blocks.map {|b| b.render }.join
  end

  def to_s
    %[#{super.to_s} - #{doctitle}]  
  end

end
