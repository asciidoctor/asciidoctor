# Public: Methods for parsing Asciidoc documents and rendering them
# using erb templates.
class Asciidoctor::Document

  include Asciidoctor

  # Public: Get the Hash of defines
  attr_reader :defines

  # Public: Get the Hash of document references
  attr_reader :references

  # Need these for pseudo-template yum
  attr_reader :header, :preamble

  # Public: Get the Array of elements (really Blocks or Sections) for the document
  attr_reader :elements

  # Public: Initialize an Asciidoc object.
  #
  # data  - The Array of Strings holding the Asciidoc source document.
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

    @reader = Reader.new(data, &block)

    # pseudo-delegation :)
    @defines = @reader.defines
    @references = @reader.references

    # Now parse @lines into elements
    while @reader.has_lines?
      @reader.skip_blank

      @elements << Lexer.next_block(@reader, self) if @reader.has_lines?
    end

    Asciidoctor.debug "Found #{@elements.size} elements in this document:"
    @elements.each do |el|
      Asciidoctor.debug el
    end

    root = @elements.first
    # Try to find a @header from the Section blocks we have (if any).
    if root.is_a?(Section) && root.level == 0
      @header = @elements.shift
      @elements = @header.blocks + @elements
      @header.clear_blocks
    end

  end

  # Make the raw source for the Document available.
  def source
    @reader.source if @reader
  end

  # We need to be able to return some semblance of a title
  def title
    return @title if @title

    if @header
      @title = @header.title || @header.name
    elsif @elements.first
      @title = @elements.first.title
      # Blocks don't have a :name method, but Sections do
      @title ||= @elements.first.name if @elements.first.respond_to? :name
    end

    @title
  end
  alias :name :title

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

  # Public: Render the Asciidoc document using erb templates
  #
  def render(options = {})
    r = renderer(options)
    html = r.render('document', self, :header => @header, :preamble => @preamble)
  end

  def content
    html_pieces = []
    @elements.each do |element|
      Asciidoctor::debug "Rendering element: #{element}"
      html_pieces << element.render
    end
    html_pieces.join("\n")
  end

end
