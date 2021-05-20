# frozen_string_literal: true
module Asciidoctor
# Public: A pluggable adapter for integrating a syntax (aka code) highlighter into AsciiDoc processing.
#
# There are two types of syntax highlighter adapters. The first performs syntax highlighting during the convert phase.
# This adapter type must define a highlight? method that returns true. The companion highlight method will then be
# called to handle the :specialcharacters substitution for source blocks. The second assumes syntax highlighting is
# performed on the client (e.g., when the HTML document is loaded). This adapter type must define a docinfo? method
# that returns true. The companion docinfo method will then be called to insert markup into the output document. The
# docinfo functionality is available to both adapter types.
#
# Asciidoctor provides several built-in adapters, including coderay, pygments, rouge, highlight.js, html-pipeline, and
# prettify. Additional adapters can be registered using SyntaxHighlighter.register or by supplying a custom factory.
module SyntaxHighlighter
  # Public: Returns the String name of this syntax highlighter for referencing it in messages and option names.
  attr_reader :name

  def initialize name, backend = 'html5', opts = {}
    @name = @pre_class = name
  end

  # Public: Indicates whether this syntax highlighter has docinfo (i.e., markup) to insert into the output document at
  # the specified location. Should be called by converter after main content has been converted.
  #
  # location - The Symbol representing the location slot (:head or :footer).
  #
  # Returns a [Boolean] indicating whether the docinfo method should be called for this location.
  def docinfo? location; end

  # Public: Generates docinfo markup for this syntax highlighter to insert at the specified location in the output document.
  # Should be called by converter after main content has been converted.
  #
  # location - The Symbol representing the location slot (:head or :footer).
  # doc      - The Document in which this syntax highlighter is being used.
  # opts     - A Hash of options that configure the syntax highlighting:
  #            :linkcss - A Boolean indicating whether the stylesheet should be linked instead of embedded (optional).
  #            :cdn_base_url - The String base URL for assets loaded from the CDN.
  #            :self_closing_tag_slash - The String '/' if the converter calling this method emits self-closing tags.
  #
  # Return the [String] markup to insert.
  def docinfo location, doc, opts
    raise ::NotImplementedError, %(#{SyntaxHighlighter} subclass #{self.class} must implement the ##{__method__} method since #docinfo? returns true)
  end

  # Public: Indicates whether highlighting is handled by this syntax highlighter or by the client.
  #
  # Returns a [Boolean] indicating whether the highlight method should be used to handle the :specialchars substitution.
  def highlight?; end

  # Public: Highlights the specified source when this source block is being converted.
  #
  # If the source contains callout marks, the caller assumes the source remains on the same lines and no closing tags
  # are added to the end of each line. If the source gets shifted by one or more lines, this method must return a
  # tuple containing the highlighted source and the number of lines by which the source was shifted.
  #
  # node   - The source Block to syntax highlight.
  # source - The raw source text String of this source block (after preprocessing).
  # lang   - The source language String specified on this block (e.g., ruby).
  # opts   - A Hash of options that configure the syntax highlighting:
  #          :callouts - A Hash of callouts extracted from the source, indexed by line number (1-based) (optional).
  #          :css_mode - The Symbol CSS mode (:class or :inline).
  #          :highlight_lines - A 1-based Array of Integer line numbers to highlight (aka emphasize) (optional).
  #          :number_lines - A Symbol indicating whether lines should be numbered (:table or :inline) (optional).
  #          :start_line_number - The starting Integer (1-based) line number (optional, default: 1).
  #          :style - The String style (aka theme) to use for colorizing the code (optional).
  #
  # Returns the highlighted source String or a tuple of the highlighted source String and an Integer line offset.
  def highlight node, source, lang, opts
    raise ::NotImplementedError, %(#{SyntaxHighlighter} subclass #{self.class} must implement the ##{__method__} method since #highlight? returns true)
  end

  # Public: Format the highlighted source for inclusion in an HTML document.
  #
  # node   - The source Block being processed.
  # lang   - The source language String for this Block (e.g., ruby).
  # opts   - A Hash of options that control syntax highlighting:
  #          :nowrap - A Boolean that indicates whether wrapping should be disabled (optional).
  #
  # Returns the highlighted source [String] wrapped in preformatted tags (e.g., pre and code)
  def format node, lang, opts
    raise ::NotImplementedError, %(#{SyntaxHighlighter} subclass #{self.class} must implement the ##{__method__} method)
  end

  # Public: Indicates whether this syntax highlighter wants to write a stylesheet to disk. Only called if both the
  # linkcss and copycss attributes are set on the document.
  #
  # doc - The Document in which this syntax highlighter is being used.
  #
  # Returns a [Boolean] indicating whether the write_stylesheet method should be called.
  def write_stylesheet? doc; end

  # Public: Writes the stylesheet to support the highlighted source(s) to disk.
  #
  # doc    - The Document in which this syntax highlighter is being used.
  # to_dir - The absolute String path of the stylesheet output directory.
  #
  # Returns nothing.
  def write_stylesheet doc, to_dir
    raise ::NotImplementedError, %(#{SyntaxHighlighter} subclass #{self.class} must implement the ##{__method__} method since #write_stylesheet? returns true)
  end

  def self.included into
    into.extend Config
  end
  private_class_method :included # use separate declaration for Ruby 2.0.x

  module Config
    # Public: Statically register the current class in the registry for the specified names.
    #
    # names - one or more String or Symbol names with which to register the current class as a syntax highlighter
    #         implementation. Symbol arguments are coerced to Strings.
    #
    # Returns nothing.
    def register_for *names
      SyntaxHighlighter.register self, *(names.map {|name| name.to_s })
    end
  end

  module Factory
    # Public: Associates the syntax highlighter class or object with the specified names.
    #
    # syntax_highlighter - the syntax highlighter implementation to register
    # names              - one or more String names with which to register this syntax highlighter implementation.
    #
    # Returns nothing.
    def register syntax_highlighter, *names
      names.each {|name| registry[name] = syntax_highlighter }
    end

    # Public: Retrieves the syntax highlighter class or object registered for the specified name.
    #
    # name - The String name of the syntax highlighter to retrieve.
    #
    # Returns the SyntaxHighlighter Class or Object instance registered for this name.
    def for name
      registry[name]
    end

    # Public: Resolves the name to a syntax highlighter instance, if found in the registry.
    #
    # name    - The String name of the syntax highlighter to create.
    # backend - The String name of the backend for which this syntax highlighter is being used (default: 'html5').
    # opts    - A Hash of options providing information about the context in which this syntax highlighter is used:
    #           :document - The Document for which this syntax highlighter was created.
    #
    # Returns a [SyntaxHighlighter] instance for the specified name.
    def create name, backend = 'html5', opts = {}
      if (syntax_hl = self.for name)
        syntax_hl = syntax_hl.new name, backend, opts if ::Class === syntax_hl
        raise ::NameError, %(#{syntax_hl.class} must specify a value for `name') unless syntax_hl.name
        syntax_hl
      end
    end

    private

    def registry
      raise ::NotImplementedError, %(#{Factory} subclass #{self.class} must implement the ##{__method__} method)
    end
  end

  class CustomFactory
    include Factory

    def initialize seed_registry = nil
      @registry = seed_registry || {}
    end

    private

    attr_reader :registry
  end

  module DefaultFactory
    include Factory

    @@registry = {}

    private

    def registry
      @@registry
    end

    unless RUBY_ENGINE == 'opal'
      public

      def register syntax_highlighter, *names
        @@mutex.owned? ? names.each {|name| @@registry = @@registry.merge name => syntax_highlighter } :
            @@mutex.synchronize { register syntax_highlighter, *names }
      end

      # This method will lazy require and register additional built-in implementations, which include coderay,
      # pygments, rouge, and prettify. Refer to {Factory#for} for parameters and return value.
      def for name
        @@registry.fetch name do
          @@mutex.synchronize do
            @@registry.fetch name do
              if (require_path = PROVIDED[name])
                require require_path
                @@registry[name]
              else
                @@registry = @@registry.merge name => nil
                nil
              end
            end
          end
        end
      end

      PROVIDED = {
        'coderay' => %(#{__dir__}/syntax_highlighter/coderay),
        'prettify' => %(#{__dir__}/syntax_highlighter/prettify),
        'pygments' => %(#{__dir__}/syntax_highlighter/pygments),
        'rouge' => %(#{__dir__}/syntax_highlighter/rouge),
      }

      @@mutex = ::Mutex.new
    end
  end

  class DefaultFactoryProxy < CustomFactory
    include DefaultFactory # inserts module into ancestors immediately after superclass

    def for name
      @registry.fetch(name) { super }
    end unless RUBY_ENGINE == 'opal'
  end

  class Base
    include SyntaxHighlighter

    def format node, lang, opts
      class_attr_val = opts[:nowrap] ? %(#{@pre_class} highlight nowrap) : %(#{@pre_class} highlight)
      if (transform = opts[:transform])
        transform[(pre = { 'class' => class_attr_val }), (code = lang ? { 'data-lang' => lang } : {})]
        # NOTE: make sure data-lang is the last attribute on the code tag to remain consistent with 1.5.x
        if (lang = code.delete 'data-lang')
          code['data-lang'] = lang
        end
        %(<pre#{pre.map {|k, v| %[ #{k}="#{v}"] }.join}><code#{code.map {|k, v| %[ #{k}="#{v}"] }.join}>#{node.content}</code></pre>)
      else
        %(<pre class="#{class_attr_val}"><code#{lang ? %[ data-lang="#{lang}"] : ''}>#{node.content}</code></pre>)
      end
    end
  end

  extend DefaultFactory # exports static methods
end
end

require_relative 'syntax_highlighter/highlightjs'
require_relative 'syntax_highlighter/html_pipeline' unless RUBY_ENGINE == 'opal'
