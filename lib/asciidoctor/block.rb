module Asciidoctor
# Public: Methods for managing blocks of Asciidoc content in a section.
#
# Examples
#
#   block = Asciidoctor::Block.new(parent, :paragraph, :source => '_This_ is a <test>')
#   block.content
#   => "<em>This</em> is a &lt;test&gt;"
class Block < AbstractBlock

  DEFAULT_CONTENT_MODEL = ::Hash.new(:simple).merge({
    # TODO should probably fill in all known blocks
    :audio => :empty,
    :image => :empty,
    :listing => :verbatim,
    :literal => :verbatim,
    :stem => :raw,
    :open => :compound,
    :page_break => :empty,
    :pass => :raw,
    :thematic_break => :empty,
    :video => :empty
  })

  # Public: Create alias for context to be consistent w/ AsciiDoc
  alias :blockname :context

  # Public: Get/Set the original Array content for this block, if applicable
  attr_accessor :lines

  # Public: Initialize an Asciidoctor::Block object.
  #
  # parent        - The parent AbstractBlock with a compound content model to which this Block will be appended.
  # context       - The Symbol context name for the type of content (e.g., :paragraph).
  # opts          - a Hash of options to customize block initialization: (default: {})
  #                 * :content_model indicates whether blocks can be nested in this Block (:compound), otherwise
  #                     how the lines should be processed (:simple, :verbatim, :raw, :empty). (default: :simple)
  #                 * :attributes a Hash of attributes (key/value pairs) to assign to this Block. (default: {})
  #                 * :source a String or Array of raw source for this Block. (default: nil)
  #--
  # QUESTION should we store source_data as lines for blocks that have compound content models?
  def initialize parent, context, opts = {}
    super
    @content_model = opts[:content_model] || DEFAULT_CONTENT_MODEL[context]
    if opts.has_key? :subs
      # FIXME this is a bit funky
      # we have to be defensive to avoid lock_in_subs wiping out the override
      if !(subs = opts[:subs]) || (subs.is_a? ::Array)
        @subs = subs || []
        @default_subs = @subs.dup
        @attributes.delete('subs')
      else
        @attributes['subs'] = %(#{subs})
      end
    end
    if !(raw_source = opts[:source])
      @lines = []
    elsif raw_source.is_a? ::String
      @lines = Helpers.normalize_lines_from_string raw_source
    else
      @lines = raw_source.dup
    end
  end

  # Public: Get the converted result of the child blocks by converting the
  # children appropriate to content model that this block supports.
  #
  # Examples
  #
  #   doc = Asciidoctor::Document.new
  #   block = Asciidoctor::Block.new(doc, :paragraph,
  #       :source => '_This_ is what happens when you <meet> a stranger in the <alps>!')
  #   block.content
  #   => "<em>This</em> is what happens when you &lt;meet&gt; a stranger in the &lt;alps&gt;!"
  def content
    case @content_model
    when :compound
      super
    when :simple
      apply_subs(@lines * EOL, @subs)
    when :verbatim, :raw
      #((apply_subs @lines.join(EOL), @subs).sub StripLineWiseRx, '\1')

      # QUESTION could we use strip here instead of popping empty lines?
      # maybe apply_subs can know how to strip whitespace?
      result = apply_subs @lines, @subs
      if result.size < 2
        result[0]
      else
        result.shift while (first = result[0]) && first.rstrip.empty?
        result.pop while (last = result[-1]) && last.rstrip.empty?
        result * EOL
      end
    else
      warn %(Unknown content model '#{@content_model}' for block: #{to_s}) unless @content_model == :empty
      nil
    end
  end

  # Public: Returns the preprocessed source of this block
  #
  # Returns the a String containing the lines joined together or nil if there
  # are no lines
  def source
    @lines * EOL
  end

  def to_s
    content_summary = @content_model == :compound ? %(blocks: #{@blocks.size}) : %(lines: #{@lines.size})
    %(#<#{self.class}@#{object_id} {context: #{@context.inspect}, content_model: #{@content_model.inspect}, style: #{@style.inspect}, #{content_summary}}>)
  end
end
end
