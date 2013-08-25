module Asciidoctor
module Extensions
  class Extension
    class << self
      def register
        ::Asciidoctor::Extensions.register self
      end

      def activate registry, document
      end
    end
  end

  class << self
    def registered?
      !@registered.nil?
    end

    def registered
      @registered ||= []
    end

    # QUESTION should we require extensions to have names?
    # how about autogenerate name for class, assume extension
    # is name of block if block is given
    # having a name makes it easier to unregister an extension
    def register extension = nil, &block
      if block_given?
        registered << block
      elsif extension
        registered << resolve_class(extension)
      end 
    end

    def resolve_class(object)
      object.is_a?(Class) ? object : class_for_name(object.to_s)
    end

    def class_for_name(qualified_name)
      qualified_name.split('::').inject(Object) do |module_, name|
        if name.empty?
          module_
        elsif module_.const_defined? name
          module_.const_get(name)
        else
          raise "Could not resolve class for name: #{qualified_name}"
        end
      end
    end

    def unregister_all
      @registered = []
    end
  end

  class Registry
    attr_accessor :preprocessors
    attr_accessor :treeprocessors
    attr_accessor :postprocessors
    attr_accessor :include_processors
    attr_accessor :blocks
    attr_accessor :block_macros
    attr_accessor :inline_macros

    def initialize document = nil
      @preprocessors = []
      @treeprocessors = []
      @postprocessors = []
      @include_processors = []
      @include_processor_cache = {}
      @block_delimiters = {}
      @blocks = {}
      @block_processor_cache = {}
      @block_macros = {}
      @block_macro_processor_cache = {}
      @inline_macros = {}
      @inline_macro_processor_cache = {}

      Extensions.registered.each do |extension|
        if extension.is_a? Proc
          register document, &extension
        else
          extension.activate self, document
        end
      end
    end 

    def preprocessor processor, position = :<<
      processor = resolve_processor_class processor
      if position == :<< || @preprocessors.empty?
        @preprocessors.push processor
      elsif position == :>>
        @preprocessors.unshift processor
      else
        @preprocessors.push processor
      end
    end

    def preprocessors?
      !@preprocessors.empty?
    end

    def load_preprocessors *args
      @preprocessors.map do |processor|
        processor.new(*args)
      end
    end

    def treeprocessor processor, position = :<<
      processor = resolve_processor_class processor
      if position == :<< || @treeprocessors.empty?
        @treeprocessors.push processor
      elsif position == :>>
        @treeprocessors.unshift processor
      else
        @treeprocessors.push processor
      end
    end

    def treeprocessors?
      !@treeprocessors.empty?
    end

    def load_treeprocessors *args
      @treeprocessors.map do |processor|
        processor.new(*args)
      end
    end

    def postprocessor processor, position = :<<
      processor = resolve_processor_class processor
      if position == :<< || @postprocessors.empty?
        @postprocessors.push processor
      elsif position == :>>
        @postprocessors.unshift processor
      else
        @postprocessors.push processor
      end
    end

    def postprocessors?
      !@postprocessors.empty?
    end

    def load_postprocessors *args
      @postprocessors.map do |processor|
        processor.new(*args)
      end
    end

    def include_processor processor, position = :<<
      processor = resolve_processor_class processor
      if position == :<< || @include_processors.empty?
        @include_processors.push processor
      elsif position == :>>
        @include_processors.unshift processor
      else
        @include_processors.push processor
      end
    end

    def include_processors?
      !@include_processors.empty?
    end

    def load_include_processors *args
      @include_processors.map do |processor|
        processor.new(*args)
      end
      # QUESTION do we need/want the cache?
      #@include_processors.map do |processor|
      #  @include_processor_cache[processor] ||= processor.new(*args)
      #end
    end

    # TODO allow contexts to be specified here, perhaps as [:upper, [:paragraph, :sidebar]]
    def block name, processor, delimiter = nil, &block
      processor = resolve_processor_class processor
      @blocks[name] = processor
      if block_given?
        @block_delimiters[block] = name
      elsif delimiter && delimiter.is_a?(Regexp)
        @block_delimiters[delimiter] = name
      end
    end

    def blocks?
      !@blocks.empty?
    end

    def block_delimiters?
      !@block_delimiters.empty?
    end

    # NOTE block delimiters not yet implemented
    def at_block_delimiter? line
      @block_delimiters.each do |delimiter, name|
        if delimiter.is_a? Proc
          if delimiter.call(line)
            return name
          end
        else
          if line.match(delimiter)
            return name
          end
        end
      end
      false
    end

    def load_block_processor name, *args
      @block_processor_cache[name] ||= @blocks[name].new(name.to_sym, *args)
    end

    def processor_registered_for_block? name, context
      if @blocks.has_key? name.to_sym
        (@blocks[name.to_sym].config.fetch(:contexts, nil) || []).include?(context)
      else
        false
      end
    end

    def block_macro name, processor
      processor = resolve_processor_class processor
      @block_macros[name.to_s] = processor
    end

    def block_macros?
      !@block_macros.empty?
    end

    def load_block_macro_processor name, *args
      @block_macro_processor_cache[name] ||= @block_macros[name].new(name, *args)
    end

    def processor_registered_for_block_macro? name
      @block_macros.has_key? name
    end

    # TODO probably need ordering control before/after other inline macros
    def inline_macro name, processor
      processor = resolve_processor_class processor
      @inline_macros[name.to_s] = processor
    end

    def inline_macros?
      !@inline_macros.empty?
    end

    def load_inline_macro_processor name, *args
      @inline_macro_processor_cache[name] ||= @inline_macros[name].new(name, *args)
    end

    def load_inline_macro_processors *args
      @inline_macros.map do |name, processor|
        load_inline_macro_processor name, *args
      end
    end

    def processor_registered_for_inline_macro? name
      @inline_macros.has_key? name
    end

    def register document, &block
      instance_exec document, &block
    end

    def resolve_processor_class object
      ::Asciidoctor::Extensions.resolve_class object
    end

    def reset
      @block_processor_cache = {}
      @block_macro_processor_cache = {}
      @inline_macro_processor_cache = {}
    end
  end

  class Processor
    def initialize(document)
      @document = document
    end
  end

  # Public: Preprocessors are run after the source text is split into lines and
  # before parsing begins.
  #
  # Prior to invoking the preprocessor, Asciidoctor splits the source text into
  # lines and normalizes them. The normalize process strips trailing whitespace
  # from each line and leaves behind a line-feed character (i.e., "\n").
  #
  # Asciidoctor passes a reference to the Reader and a copy of the lines Array
  # to the process method of an instance of each registered Preprocessor. The
  # Preprocessor modifies the Array as necessary and either returns a reference
  # to the same Reader or a reference to a new one.
  #
  # Preprocessors must extend Asciidoctor::Extensions::Preprocessor.
  class Preprocessor < Processor
    # Public: Accepts the Reader and an Array of lines, modifies them as
    # needed, then returns the Reader or a reference to a new one.
    #
    # Each subclass of Preprocessor should override this method.
    def process reader, lines
      reader
    end
  end

  # Public: Treeprocessors are run on the Document after the source has been
  # parsed into an abstract syntax tree, as represented by the Document object
  # and its child Node objects.
  #
  # Asciidoctor invokes the process method on an instance of each registered
  # Treeprocessor.
  #
  # QUESTION should the treeprocessor get invoked after parse header too?
  #
  # Treeprocessors must extend Asciidoctor::Extensions::Treeprocessor.
  class Treeprocessor < Processor
    def process
    end
  end

  # Public: Postprocessors are run after the document is rendered and before
  # it's written to the output stream.
  #
  # Asciidoctor passes a reference to the output String to the process method
  # of each registered Postprocessor. The Preprocessor modifies the String as
  # necessary and returns the String replacement.
  #
  # The markup format in the String is determined from the backend used to
  # render the Document. The backend and be looked up using the backend method
  # on the Document object, as well as various backend-related document
  # attributes.
  #
  # Postprocessors can also be used to relocate assets needed by the published
  # document.
  #
  # Postprocessors must extend Asciidoctor::Extensions::Postprocessor.
  class Postprocessor < Processor
    def process output
      output
    end
  end

  # Public: IncludeProcessors are used to process include::[] macros in the
  # source document.
  #
  # When Asciidoctor discovers an include::[] macro in the source document, it
  # iterates through the IncludeProcessors and delegates the work of reading
  # the content to the first processor that identifies itself as capable of
  # handling that target.
  #
  # IncludeProcessors must extend Asciidoctor::Extensions::IncludeProcessor.
  class IncludeProcessor < Processor
    def process target, attributes
      output
    end
  end

  # Supported options:
  # * :contexts - The blocks contexts (types) on which this style can be used (default: [:paragraph, :open]
  # * :content_model - The structure of the content supported in this block (default: :compound)
  # * :pos_attrs - A list of attribute names used to map positional attributes (default: nil)
  # * :default_attrs - Set default values for attributes (default: nil)
  # * ...
  class BlockProcessor < Processor
    class << self
      def config
        @config ||= {:contexts => [:paragraph, :open]}
      end

      def option(key, default_value)
        config[key] = default_value
      end
    end

    attr_reader :document
    attr_reader :context
    attr_reader :options

    def initialize(context, document, opts = {})
      super(document)
      @context = context
      @options = self.class.config.dup
      opts.delete(:contexts) # contexts can't be overridden
      @options.update(opts)
      #@options[:contexts] ||= [:paragraph, :open]
      @options[:content_model] ||= :compound
    end

    def process parent, reader, attributes
      nil
    end
  end

  class MacroProcessor < Processor
    class << self
      def config
        @config ||= {}
      end

      def option(key, default_value)
        config[key] = default_value
      end
    end

    attr_reader :document
    attr_reader :name
    attr_reader :options

    def initialize(name, document, opts = {})
      super(document)
      @name = name
      @options = self.class.config.dup
      @options.update(opts)
    end

    def process parent, target, attributes, source = nil
      nil
    end
  end

  class BlockMacroProcessor < MacroProcessor
  end

  # TODO break this out into different pattern types
  # for example, FormalInlineMacro, ShortInlineMacro (no target) and other patterns
  class InlineMacroProcessor < MacroProcessor
    def initialize(name, document, opts = {})
      super
      @regexp = nil
    end

    def regexp
      if @options[:short_form]
        @regexp ||= %r(\\?#{@name}:\[((?:\\\]|[^\]])*?)\])
      else
        @regexp ||= %r(\\?#{@name}:(\S+?)\[((?:\\\]|[^\]])*?)\])
      end
    end
  end
end
end
