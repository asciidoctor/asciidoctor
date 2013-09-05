module Asciidoctor
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
class Document < AbstractBlock

  Footnote = Struct.new(:index, :id, :text)
  AttributeEntry = Struct.new(:name, :value, :negate) do
    def initialize(name, value, negate = nil)
      super(name, value, negate.nil? ? value.nil? : false)
    end

    def save_to(block_attributes)
      (block_attributes[:attribute_entries] ||= []) << self
    end

    #def save_to_next_block(document)
    #  (document.attributes[:pending_attribute_entries] ||= []) << self
    #end
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
  #   puts doc.render
  def initialize(data = [], options = {})
    super(self, :document)

    if options[:parent]
      @parent_document = options.delete(:parent)
      options[:base_dir] ||= @parent_document.base_dir
      # QUESTION should we support setting attribute in parent document from nested document?
      # NOTE we must dup or else all the assignments to the overrides clobbers the real attributes
      @attribute_overrides = @parent_document.attributes.dup
      @safe = @parent_document.safe
      @renderer = @parent_document.renderer
      initialize_extensions = false
      @extensions = @parent_document.extensions
    else
      @parent_document = nil
      # copy attributes map and normalize keys
      # attribute overrides are attributes that can only be set from the commandline
      # a direct assignment effectively makes the attribute a constant
      # a nil value or name with leading or trailing ! will result in the attribute being unassigned
      @attribute_overrides = (options[:attributes] || {}).inject({}) do |collector,(key,value)|
        if key.start_with?('!')
          key = key[1..-1]
          value = nil
        elsif key.end_with?('!')
          key = key[0..-2]
          value = nil
        end
        collector[key.downcase] = value
        collector
      end
      @safe = nil
      @renderer = nil
      initialize_extensions = Asciidoctor.const_defined?('Extensions')
      @extensions = nil # initialize furthur down
    end

    @header = nil
    @references = {
      :ids => {},
      :footnotes => [],
      :links => [],
      :images => [],
      :indexterms => [],
      :includes => Set.new,
    }
    @counters = {}
    @callouts = Callouts.new
    @attributes_modified = Set.new
    @options = options
    unless @parent_document
      # safely resolve the safe mode from const, int or string
      if @safe.nil? && !(safe_mode = @options[:safe])
        @safe = SafeMode::SECURE
      elsif safe_mode.is_a?(Fixnum)
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
    @options[:header_footer] = @options.fetch(:header_footer, false)

    @attributes['encoding'] = 'UTF-8'
    @attributes['sectids'] = ''
    @attributes['notitle'] = '' unless @options[:header_footer]
    @attributes['toc-placement'] = 'auto'
    @attributes['stylesheet'] = ''
    @attributes['copycss'] = '' if @options[:header_footer]
    @attributes['prewrap'] = ''
    @attributes['attribute-undefined'] = COMPLIANCE[:attribute_undefined]
    @attributes['attribute-missing'] = COMPLIANCE[:attribute_missing]

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
    @attribute_overrides['embedded'] = @options[:header_footer] ? nil : ''

    # the only way to set the max-include-depth attribute is via the document options
    # 64 is the AsciiDoc default
    @attribute_overrides['max-include-depth'] ||= 64

    # the only way to enable uri reads is via the document options, disabled by default
    unless !@attribute_overrides['allow-uri-read'].nil?
      @attribute_overrides['allow-uri-read'] = nil
    end

    # if the base_dir option is specified, it overrides docdir as the root for relative paths
    # otherwise, the base_dir is the directory of the source file (docdir) or the current
    # directory of the input is a string
    if @options[:base_dir].nil?
      if @attribute_overrides['docdir']
        @base_dir = @attribute_overrides['docdir'] = File.expand_path(@attribute_overrides['docdir'])
      else
        #warn 'asciidoctor: WARNING: setting base_dir is recommended when working with string documents' unless nested?
        @base_dir = @attribute_overrides['docdir'] = File.expand_path(Dir.pwd)
      end
    else
      @base_dir = @attribute_overrides['docdir'] = File.expand_path(@options[:base_dir])
    end

    # allow common attributes backend and doctype to be set using options hash
    unless @options[:backend].nil?
      @attribute_overrides['backend'] = @options[:backend].to_s
    end

    unless @options[:doctype].nil?
      @attribute_overrides['doctype'] = @options[:doctype].to_s
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
        if val.is_a?(String) && val.end_with?('@')
          val = val.chop
          verdict = true
        end
        @attributes[key] = val
      end
      verdict
    }

    if !@parent_document
      # setup default backend and doctype
      @attributes['backend'] ||= DEFAULT_BACKEND
      @attributes['doctype'] ||= DEFAULT_DOCTYPE
      update_backend_attributes

      #@attributes['indir'] = @attributes['docdir']
      #@attributes['infile'] = @attributes['docfile']

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

      # fallback directories
      @attributes['stylesdir'] ||= '.'
      @attributes['iconsdir'] ||= File.join(@attributes.fetch('imagesdir', './images'), 'icons')

      @extensions = initialize_extensions ? Extensions::Registry.new(self) : nil
      @reader = PreprocessorReader.new self, data, Asciidoctor::Reader::Cursor.new(@attributes['docfile'], @base_dir)

      if @extensions && @extensions.preprocessors?
        @extensions.load_preprocessors(self).each do |processor|
          @reader = processor.process(@reader, @reader.lines) || @reader
        end
      end
    else
      # don't need to do the extra processing within our own document
      # FIXME line info isn't reported correctly within include files in nested document
      @reader = Reader.new data, options[:cursor]
    end

    # Now parse the lines in the reader into blocks
    Lexer.parse(@reader, self, :header_only => @options.fetch(:parse_header_only, false)) 

    @callouts.rewind

    if !@parent_document && @extensions && @extensions.treeprocessors?
      @extensions.load_treeprocessors(self).each do |processor|
        processor.process
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

  def footnotes?
    not @references[:footnotes].empty?
  end

  def footnotes
    @references[:footnotes]
  end

  def nested?
    @parent_document ? true : false
  end

  def embedded?
    # QUESTION should this be !@options[:header_footer] ?
    @attributes.has_key? 'embedded'
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

  def doctype
    @attributes['doctype']
  end

  def backend
    @attributes['backend']
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
    elsif !(sect = first_section).nil? && sect.title?
      val = sect.title
    else
      return nil
    end
    
    if opts[:sanitize] && val.include?('<')
      val.gsub(/<[^>]+>/, '').tr_s(' ', ' ').strip
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

  # QUESTION move to AbstractBlock?
  def first_section
    has_header? ? @header : (@blocks || []).detect{|e| e.is_a? Section}
  end

  def has_header?
    @header ? true : false
  end

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

    unless @attributes.has_key?('doctitle') || (val = doctitle).nil?
      @attributes['doctitle'] = val
    end

    # css-signature cannot be updated after header attributes are processed
    if !@id && @attributes.has_key?('css-signature')
      @id = @attributes['css-signature']
    end

    toc_val = @attributes['toc']
    toc2_val = @attributes['toc2']
    toc_position_val = @attributes['toc-position']

    if (!toc_val.nil? && (toc_val != '' || toc_position_val.to_s != '')) || !toc2_val.nil?
      default_toc_position = 'left'
      default_toc_class = 'toc2'
      position = [toc_position_val, toc2_val, toc_val].find {|pos| pos.to_s != ''}
      position = default_toc_position if !position && !toc2_val.nil?
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
      when 'center'
        @attributes.delete('toc2')
        default_toc_class = nil
        default_toc_position = 'center'
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
      @attributes_modified << name
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
      if !m[1].empty?
        subs = resolve_pass_subs m[1]
        subs.empty? ? m[2] : apply_subs(m[2], subs)
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
    basebackend = backend.sub(REGEXP[:trailing_digit], '')
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

  def renderer(opts = {})
    return @renderer if @renderer
    
    render_options = {}

    # Load up relevant Document @options
    if @options.has_key? :template_dir
      render_options[:template_dirs] = [@options[:template_dir]]
    elsif @options.has_key? :template_dirs
      render_options[:template_dirs] = @options[:template_dirs]
    end
    
    render_options[:template_cache] = @options.fetch(:template_cache, true)
    render_options[:backend] = @attributes.fetch('backend', 'html5')
    render_options[:template_engine] = @options[:template_engine]
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

    # QUESTION should we add Preserializeprocessors? is it the right name?
    #if !@parent_document && @extensions && @extensions.preserializeprocessors?
    #  @extensions.load_preserializeprocessors(self).each do |processor|
    #    processor.process r
    #  end
    #end

    if doctype == 'inline'
      # QUESTION should we warn if @blocks.size > 0 and the first block is not a paragraph?
      if !(block = @blocks.first).nil? && block.content_model != :compound
        output = block.content
      else
        output = ''
      end
    else
      output = @options.merge(opts)[:header_footer] ? r.render('document', self).strip : r.render('embedded', self)
    end

    if !@parent_document && @extensions
      if @extensions.postprocessors?
        @extensions.load_postprocessors(self).each do |processor|
          output = processor.process output
        end
      end
      @extensions.reset
    end

    output
  end

  def content
    # per AsciiDoc-spec, remove the title before rendering the body,
    # regardless of whether the header is rendered)
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
        content = sub_attributes(content.lines.entries).join unless content.nil?
      end

      if (docinfo || docinfo2) && @attributes.has_key?('docname')
        docinfo_path = normalize_system_path("#{@attributes['docname']}-#{docinfo_filename}")
        content2 = read_asset(docinfo_path)
        unless content2.nil?
          content2 = sub_attributes(content2.lines.entries).join
          content = content.nil? ? content2 : "#{content}\n#{content2}"
        end
      end

      # to_s forces nil to empty string
      content.to_s
    end
  end

  def to_s
    %[#{super.to_s} - #{doctitle}]  
  end

end
end
