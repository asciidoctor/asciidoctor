# encoding: UTF-8
module Asciidoctor
# Public: Methods for managing blocks of Asciidoc content in a section.
#
# Examples
#
#   block = Asciidoctor::Block.new(parent, :paragraph, :source => '_This_ is a <test>')
#   block.content
#   => "<em>This</em> is a &lt;test&gt;"
class Block < AbstractBlock

  (DEFAULT_CONTENT_MODEL = {
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
  }).default = :simple

  # Public: Create alias for context to be consistent w/ AsciiDoc
  alias blockname context

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
  #
  # IMPORTANT: If you don't specify the `:subs` option, you must explicitly call
  # the `lock_in_subs` method to resolve and assign the substitutions to this
  # block (which are resolved from the `subs` attribute, if specified, or the
  # default substitutions based on this block's context). If you want to use the
  # default subs for a block, pass the option `:subs => :default`. You can
  # override the default subs using the `:default_subs` option.
  #--
  # QUESTION should we store source_data as lines for blocks that have compound content models?
  def initialize parent, context, opts = {}
    super
    @content_model = opts[:content_model] || DEFAULT_CONTENT_MODEL[context]
    if opts.key? :subs
      # FIXME feels funky; we have to be defensive to get lock_in_subs to honor override
      # FIXME does not resolve substitution groups inside Array (e.g., [:normal])
      if (subs = opts[:subs])
        # e.g., :subs => :defult
        # subs attribute is honored; falls back to opts[:default_subs], then built-in defaults based on context
        if subs == :default
          @default_subs = opts[:default_subs]
        # e.g., :subs => [:quotes]
        # subs attribute is not honored
        elsif ::Array === subs
          @default_subs = subs.dup
          @attributes.delete 'subs'
        # e.g., :subs => :normal or :subs => 'normal'
        # subs attribute is not honored
        else
          @default_subs = nil
          # interpolation is the fastest way to dup subs as a string
          @attributes['subs'] = %(#{subs})
        end
        # resolve the subs eagerly only if subs option is specified
        lock_in_subs
      # e.g., :subs => nil
      else
        # NOTE @subs is initialized as empty array by super constructor
        # prevent subs from being resolved
        @default_subs = []
        @attributes.delete 'subs'
      end
    # defer subs resolution; subs attribute is honored
    else
      # NOTE @subs is initialized as empty array by super constructor
      # QUESTION should we honor :default_subs option (i.e., @default_subs = opts[:default_subs])?
      @default_subs = nil
    end
    if (raw_source = opts[:source]).nil_or_empty?
      @lines = []
    elsif ::String === raw_source
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
      apply_subs @lines * LF, @subs
    when :verbatim, :raw
      #((apply_subs @lines * LF, @subs).sub StripLineWiseRx, '\1')

      # QUESTION could we use strip here instead of popping empty lines?
      # maybe apply_subs can know how to strip whitespace?
      result = apply_subs @lines, @subs
      if result.size < 2
        result[0]
      else
        result.shift while (first = result[0]) && first.rstrip.empty?
        result.pop while (last = result[-1]) && last.rstrip.empty?
        result * LF
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
    @lines * LF
  end

  def to_s
    content_summary = @content_model == :compound ? %(blocks: #{@blocks.size}) : %(lines: #{@lines.size})
    %(#<#{self.class}@#{object_id} {context: #{@context.inspect}, content_model: #{@content_model.inspect}, style: #{@style.inspect}, #{content_summary}}>)
  end
end
end
