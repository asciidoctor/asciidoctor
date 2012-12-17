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
# notitle - The h1 heading should not be shown
# noheader - The header block (h1 heading, author, revision info) should not be shown
class Asciidoctor::Document

  include Asciidoctor

  # Public: Get the Hash of attributes
  attr_reader :attributes

  # Public: Get the Hash of document references
  attr_reader :references

  # The section level 0 element
  attr_reader :header

  # Public: Get the Array of elements (really Blocks or Sections) for the document
  attr_reader :elements

  # Public: Initialize an Asciidoc object.
  #
  # data - The Array of Strings holding the Asciidoc source document.
  # options - A Hash of options to control processing, such as disabling
  #           the header/footer (:header_footer) or attribute overrides (:attributes)
  # block - A block that can be used to retrieve external Asciidoc
  #         data to include in this document.
  #
  # Examples
  #
  #   data = File.readlines(filename)
  #   doc  = Asciidoctor::Document.new(data)
  def initialize(data, options = {}, &block)
    @elements = []
    @options = options
    @options[:header_footer] = @options.fetch(:header_footer, true)

    @attributes = {}
    @attributes['sectids'] = nil
    @attributes['encoding'] = 'UTF-8'

    @reader = Reader.new(data, @attributes, &block)

    # pseudo-delegation :)
    @references = @reader.references

    # dynamic intrinstic attribute values
    @attributes['doctype'] ||= DEFAULT_DOCTYPE
    now = Time.new
    @attributes['localdate'] ||= now.strftime('%Y-%m-%d')
    @attributes['localtime'] ||= now.strftime('%H:%m:%S %Z')
    @attributes['localdatetime'] ||= [@attributes['localdate'], @attributes['localtime']].join(' ')
    @attributes['asciidoctor-version'] = VERSION
    if options.has_key? :attributes
      @attributes.update(options[:attributes])
    end

    # Now parse @lines into elements
    while @reader.has_lines?
      @reader.skip_blank

      if @reader.has_lines?
        block = Lexer.next_block(@reader, self)
        @elements << block unless block.nil?
      end
    end

    Asciidoctor.debug "Found #{@elements.size} elements in this document:"
    @elements.each do |el|
      Asciidoctor.debug el
    end

    # split off the level 0 section, if present
    root = @elements.first
    if root.is_a?(Section) && root.level == 0
      @header = @elements.shift
      # a book has multiple level 0 sections
      if doctype == 'book'
        @elements = @header.blocks + @elements
      # an article only has one level 0 section
      else
        @elements = @header.blocks
      end
      @header.clear_blocks
    end

  end

  # Make the raw source for the Document available.
  def source
    @reader.source if @reader
  end

  def attr(name, default = nil)
    default.nil? ? @attributes[name.to_s] : @attributes.fetch(name.to_s, default)
    #default.nil? ? @attributes[name.to_s.tr('_', '-')] : @attributes.fetch(name.to_s.tr('_', '-'), default)
  end

  def attr?(name)
    @attributes.has_key? name.to_s
    #@attributes.has_key? name.to_s.tr('_', '-')
  end

  def doctype
    @attributes['doctype']
  end

  def level
    0
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
    has_header ? @header : @elements.detect{|e| e.is_a? Section}
  end

  def has_header
    !@header.nil?
  end

  def splain
    if @header
      Asciidoctor.debug "Header is #{@header}"
    else
      Asciidoctor.debug "No header"
    end

    Asciidoctor.debug "I have #{@elements.count} elements"
    @elements.each_with_index do |block, i|
      Asciidoctor.debug "v" * 60
      Asciidoctor.debug "Block ##{i} is a #{block.class}"
      Asciidoctor.debug "Name is #{block.name rescue 'n/a'}"
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
    @options.merge(options)[:header_footer] ? r.render('document', self) : content
  end

  def content
    # per AsciiDoc-spec, remove the title after rendering the header
    @attributes.delete('title')

    html_pieces = []
    @elements.each do |element|
      Asciidoctor::debug "Rendering element: #{element}"
      html_pieces << element.render
    end
    html_pieces.join
  end

end
