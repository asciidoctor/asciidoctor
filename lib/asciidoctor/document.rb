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

  # Public: Get the Hash of document references
  attr_reader :references

  # Public: Get the Hash of callouts
  attr_reader :callouts

  # Public: The section level 0 block
  attr_reader :header

  # Public: Base directory for rendering this document
  attr_reader :base_dir

  # Public: Initialize an Asciidoc object.
  #
  # data    - The Array of Strings holding the Asciidoc source document. (default: [])
  # options - A Hash of options to control processing, such as disabling
  #           the header/footer (:header_footer) or attribute overrides (:attributes)
  #           (default: {})
  # block   - A block that can be used to retrieve external Asciidoc
  #           data to include in this document.
  #
  # Examples
  #
  #   data = File.readlines(filename)
  #   doc  = Asciidoctor::Document.new(data)
  def initialize(data = [], options = {}, &block)
    super(self, :document)
    @references = {}
    @callouts = Callouts.new
    @renderer = nil
    @options = options
    @options[:header_footer] = @options.fetch(:header_footer, true)
    @base_dir = options[:base_dir] || Dir.pwd

    @attributes['sectids'] = true
    @attributes['encoding'] = 'UTF-8'

    attribute_overrides = options[:attributes] || {}

    # the only way to set the safe-paths attribute is via the document options
    attribute_overrides['safe-paths'] ||= true
    # the only way to set the include-depth attribute is via the document options
    # 10 is the AsciiDoc default, though currently Asciidoctor only supports 1 level
    attribute_overrides['include-depth'] ||= 1

    attribute_overrides['docdir'] ||= Dir.pwd
    
    attribute_overrides.each {|key, val|
      # a nil or negative key undefines the attribute 
      if (val.nil? || key[-1..-1] == '!')
        @attributes.delete(key.chomp '!')
      # otherwise it's an attribute assignment
      else
        @attributes[key] = val
      end
    }

    @attributes['backend'] ||= DEFAULT_BACKEND
    update_backend_attributes

    @reader = Reader.new(data, self, attribute_overrides, &block)

    # dynamic intrinstic attribute values
    @attributes['doctype'] ||= DEFAULT_DOCTYPE

    now = Time.new
    @attributes['localdate'] ||= now.strftime('%Y-%m-%d')
    @attributes['localtime'] ||= now.strftime('%H:%m:%S %Z')
    @attributes['localdatetime'] ||= [@attributes['localdate'], @attributes['localtime']].join(' ')
    
    # docdate and doctime should default to localdate and localtime if not otherwise set
    @attributes['docdate'] ||= @attributes['localdate']
    @attributes['doctime'] ||= @attributes['localtime']
    
    @attributes['asciidoctor-version'] = VERSION
    @attributes['iconsdir'] ||= File.join(@attributes.fetch('imagesdir', 'images'), 'icons')

    # Now parse @lines into blocks
    while @reader.has_lines?
      @reader.skip_blank

      if @reader.has_lines?
        block = Lexer.next_block(@reader, self)
        self << block unless block.nil?
      end
    end

    @callouts.rewind

    Asciidoctor.debug "Found #{@blocks.size} blocks in this document:"
    @blocks.each do |el|
      Asciidoctor.debug el
    end

    # split off the level 0 section, if present
    root = @blocks.first
    @header = nil
    if root.is_a?(Section) && root.level == 0
      @header = @blocks.shift
      # a book has multiple level 0 sections
      if doctype == 'book'
        @blocks = @header.blocks + @blocks
      # an article only has one level 0 section
      else
        @blocks = @header.blocks
      end
      @header.clear_blocks
    end

  end

  # Make the raw source for the Document available.
  def source
    @reader.source if @reader
  end

  def doctype
    @attributes['doctype']
  end

  # The title explicitly defined in the document attributes
  def title
    @attributes['title']
  end

  # We need to be able to return some semblance of a title
  def doctitle
    if !(title = @attributes.fetch('title', '')).empty?
      title
    elsif !(sect = first_section).nil? && !sect.title.empty?
      sect.title
    else
      nil
    end
  end
  alias :name :doctitle

  def notitle
    @attributes.has_key? 'notitle'
  end

  def noheader
    @attributes.has_key? 'noheader'
  end

  def first_section
    has_header? ? @header : @blocks.detect{|e| e.is_a? Section}
  end

  def has_header?
    !@header.nil?
  end

  # Public: Update the backend attributes to reflect a change in the selected backend
  def update_backend_attributes()
    backend = @attributes['backend']
    basebackend = backend.sub(/[[:digit:]]+$/, '')
    @attributes['backend-' + backend] = 1
    @attributes['basebackend'] = basebackend
    @attributes['basebackend-' + basebackend] = 1
  end

  def splain
    if @header
      Asciidoctor.debug "Header is #{@header}"
    else
      Asciidoctor.debug "No header"
    end

    Asciidoctor.debug "I have #{@blocks.count} blocks"
    @blocks.each_with_index do |block, i|
      Asciidoctor.debug "v" * 60
      Asciidoctor.debug "Block ##{i} is a #{block.class}"
      Asciidoctor.debug "Name is #{block.title rescue 'n/a'}"
      block.splain(0) if block.respond_to? :splain
      Asciidoctor.debug "^" * 60
    end
    nil
  end

  def renderer(options = {})
    return @renderer if @renderer
    
    render_options = {}

    # Load up relevant Document @options
    if @options[:template_dir]
      render_options[:template_dir] = @options[:template_dir]
    end
    
    render_options[:backend] = @attributes.fetch('backend', 'html5')
    
    # Override Document @option settings with options passed in
    render_options.merge! options

    @renderer = Renderer.new(render_options)
  end

  # Public: Render the Asciidoc document using the templates
  # loaded by Renderer. If a :template_dir is not specified,
  # or a template is missing, the renderer will fall back to
  # using the appropriate built-in template.
  def render(options = {})
    r = renderer(options)
    @options.merge(options)[:header_footer] ? r.render('document', self) : r.render('embedded', self)
  end

  def content
    # per AsciiDoc-spec, remove the title after rendering the header
    @attributes.delete('title')

    buffer = []
    @blocks.each do |block|
      Asciidoctor::debug "Rendering block: #{block}"
      buffer << block.render
    end

    buffer.join
  end

end
