# frozen_string_literal: true
(require 'asciidoctor' unless defined? Asciidoctor.load) unless RUBY_ENGINE == 'opal'

module Asciidoctor
# Extensions provide a way to participate in the parsing and converting
# phases of the AsciiDoc processor or extend the AsciiDoc syntax.
#
# The various extensions participate in AsciiDoc processing as follows:
#
# 1. After the source lines are normalized, {Preprocessor}s modify or replace
#    the source lines before parsing begins.  {IncludeProcessor}s are used to
#    process include directives for targets which they claim to handle.
# 2. The Parser parses the block-level content into an abstract syntax tree.
#    Custom blocks and block macros are processed by associated {BlockProcessor}s
#    and {BlockMacroProcessor}s, respectively.
# 3. {TreeProcessor}s are run on the abstract syntax tree.
# 4. Conversion of the document begins, at which point inline markup is processed
#    and converted. Custom inline macros are processed by associated {InlineMacroProcessor}s.
# 5. {Postprocessor}s modify or replace the converted document.
# 6. The output is written to the output stream.
#
# Extensions may be registered globally using the {Extensions.register} method
# or added to a custom {Registry} instance and passed as an option to a single
# Asciidoctor processor.
module Extensions

  # Public: An abstract base class for document and syntax processors.
  #
  # This class provides access to a class-level Hash for holding default
  # configuration options defined using the {Processor.option} method. This
  # style of default configuration is specific to the native Ruby environment
  # and is only consulted inside the initializer. An overriding configuration
  # Hash can be passed to the initializer. Once the processor is initialized,
  # the configuration is accessed using the {Processor#config} instance variable.
  #
  # Instances of the Processor class provide convenience methods for creating
  # AST nodes, such as Block and Inline, and for parsing child content.
  class Processor
    class << self
      # Public: Get the static configuration for this processor class.
      #
      # Returns a configuration [Hash]
      def config
        @config ||= {}
      end

      # Public: Assigns a default value for the specified option that gets
      # applied to all instances of this processor.
      #
      # Examples
      #
      #   option :contexts, [:open, :paragraph]
      #
      # Returns nothing
      def option key, default_value
        config[key] = default_value
      end

      # Mixes the DSL class for this processor into this processor class or instance.
      #
      # This method automatically detects whether to use the include or extend keyword to mix in the module.
      #
      # NOTE Inspiration for this DSL design comes from https://corcoran.io/2013/09/04/simple-pattern-ruby-dsl/
      #
      # Returns self
      def enable_dsl
        if const_defined? :DSL
          if singleton_class?
            include const_get :DSL
          else
            extend const_get :DSL
          end
        end
      end
      alias use_dsl enable_dsl
    end

    # Public: Get the configuration Hash for this processor instance.
    attr_reader :config

    def initialize config = {}
      @config = self.class.config.merge config
    end

    def update_config config
      @config.update config
    end

    def process *args
      raise ::NotImplementedError, %(#{Processor} subclass #{self.class} must implement the ##{__method__} method)
    end

    # QUESTION should attributes be an option instead of a parameter?

    # Public: Creates a new Section node.
    #
    # Creates a Section node in the same manner as the parser.
    #
    # parent - The parent Section (or Document) of this new Section.
    # title  - The String title of the new Section.
    # attrs  - A Hash of attributes to control how the section is built.
    #          Use the style attribute to set the name of a special section (ex. appendix).
    #          Use the id attribute to assign an explicit ID or set the value to false to
    #          disable automatic ID generation (when sectids document attribute is set).
    # opts   - An optional Hash of options (default: {}):
    #          :level    - [Integer] The level to assign to this section; defaults to
    #                      one greater than the parent level (optional).
    #          :numbered - [Boolean] A flag to force numbering, which falls back to the
    #                      state of the sectnums document attribute (optional).
    #
    # Returns a [Section] node with all properties properly initialized.
    def create_section parent, title, attrs, opts = {}
      doc = parent.document
      book = (doctype = doc.doctype) == 'book'
      level = opts[:level] || parent.level + 1
      if (style = attrs.delete 'style')
        if book && style == 'abstract'
          sectname, level = 'chapter', 1
        else
          sectname, special = style, true
          level = 1 if level == 0
        end
      elsif book
        sectname = level == 0 ? 'part' : (level > 1 ? 'section' : 'chapter')
      elsif doctype == 'manpage' && (title.casecmp 'synopsis') == 0
        sectname, special = 'synopsis', true
      else
        sectname = 'section'
      end
      sect = Section.new parent, level
      sect.title, sect.sectname = title, sectname
      if special
        sect.special = true
        if opts.fetch :numbered, (style == 'appendix')
          sect.numbered = true
        elsif !(opts.key? :numbered) && (doc.attr? 'sectnums', 'all')
          sect.numbered = book && level == 1 ? :chapter : true
        end
      elsif level > 0
        if opts.fetch :numbered, (doc.attr? 'sectnums')
          sect.numbered = sect.special ? parent.numbered && true : true
        end
      else
        sect.numbered = true if opts.fetch :numbered, (book && (doc.attr? 'partnums'))
      end
      if (id = attrs['id']) == false
        attrs.delete 'id'
      else
        sect.id = attrs['id'] = id || ((doc.attr? 'sectids') ? (Section.generate_id sect.title, doc) : nil)
      end
      sect.update_attributes attrs
      sect
    end

    def create_block parent, context, source, attrs, opts = {}
      Block.new parent, context, { source: source, attributes: attrs }.merge(opts)
    end

    # Public: Creates a list node and links it to the specified parent.
    #
    # parent - The parent Block (Block, Section, or Document) of this new list block.
    # context - The list context (e.g., :ulist, :olist, :colist, :dlist)
    # attrs  - A Hash of attributes to set on this list block
    #
    # Returns a [List] node with all properties properly initialized.
    def create_list parent, context, attrs = nil
      list = List.new parent, context
      list.update_attributes attrs if attrs
      list
    end

    # Public: Creates a list item node and links it to the specified parent.
    #
    # parent - The parent List of this new list item block.
    # text   - The text of the list item.
    #
    # Returns a [ListItem] node with all properties properly initialized.
    def create_list_item parent, text = nil
      ListItem.new parent, text
    end

    # Public: Creates an image block node and links it to the specified parent.
    #
    # parent - The parent Block (Block, Section, or Document) of this new image block.
    # attrs  - A Hash of attributes to control how the image block is built.
    #          Use the target attribute to set the source of the image.
    #          Use the alt attribute to specify an alternative text for the image.
    # opts   - An optional Hash of options (default: {})
    #
    # Returns a [Block] node with all properties properly initialized.
    def create_image_block parent, attrs, opts = {}
      unless (target = attrs['target'])
        raise ::ArgumentError, 'Unable to create an image block, target attribute is required'
      end
      attrs['alt'] ||= (attrs['default-alt'] = Helpers.basename(target, true).tr('_-', ' '))
      title = (attrs.key? 'title') ? (attrs.delete 'title') : nil
      block = create_block parent, :image, nil, attrs, opts
      if title
        block.title = title
        block.assign_caption (attrs.delete 'caption'), 'figure'
      end
      block
    end

    def create_inline parent, context, text, opts = {}
      Inline.new parent, context, text, context == :quoted ? ({ type: :unquoted }.merge opts) : opts
    end

    # Public: Parses blocks in the content and attaches the block to the parent.
    #
    # Returns The parent node into which the blocks are parsed.
    #--
    # QUESTION is parse_content the right method name? should we wrap in open block automatically?
    def parse_content parent, content, attributes = nil
      reader = Reader === content ? content : (Reader.new content)
      Parser.parse_blocks reader, parent, attributes
      parent
    end

    # Public: Parses the attrlist String into a Hash of attributes
    #
    # block    - the current AbstractBlock or the parent AbstractBlock if there is no current block (used for applying subs)
    # attrlist - the list of attributes as a String
    # opts     - an optional Hash of options to control processing:
    #            :positional_attributes - an Array of attribute names to map positional arguments to (optional, default: false)
    #            :sub_attributes - enables attribute substitution on the attrlist argument (optional, default: false)
    #
    # Returns a Hash of parsed attributes
    def parse_attributes block, attrlist, opts = {}
      return {} if attrlist ? attrlist.empty? : true
      attrlist = block.sub_attributes attrlist if opts[:sub_attributes] && (attrlist.include? ATTR_REF_HEAD)
      (AttributeList.new attrlist).parse (opts[:positional_attributes] || [])
    end

    # TODO fill out remaining methods
    [
      [:create_paragraph,     :create_block,  :paragraph],
      [:create_open_block,    :create_block,  :open],
      [:create_example_block, :create_block,  :example],
      [:create_pass_block,    :create_block,  :pass],
      [:create_listing_block, :create_block,  :listing],
      [:create_literal_block, :create_block,  :literal],
      [:create_anchor,        :create_inline, :anchor],
      [:create_inline_pass,   :create_inline, :quoted],
    ].each do |method_name, delegate_method_name, context|
      define_method method_name do |*args|
        args.unshift args.shift, context
        send delegate_method_name, *args
      end
    end
  end

  # Internal: Overlays a builder DSL for configuring the Processor instance.
  # Includes a method to define configuration options and another to define the
  # {Processor#process} method.
  module ProcessorDsl
    def option key, value
      config[key] = value
    end

    def process *args, &block
      if block_given?
        raise ::ArgumentError, %(wrong number of arguments (given #{args.size}, expected 0)) unless args.empty?
        unless block.binding && self == block.binding.receiver
          # NOTE remap self in process method to processor instance
          context = self
          block.define_singleton_method(:call) {|*m_args| context.instance_exec(*m_args, &block) }
        end
        @process_block = block
      # TODO enable if we want to support passing proc or lambda as argument instead of block
      #elsif ::Proc === args[0]
      #  raise ::ArgumentError, %(wrong number of arguments (given #{args.size - 1}, expected 0)) unless args.size == 1
      #  @process_block = args.shift
      elsif defined? @process_block
        @process_block.call(*args)
      else
        raise ::NotImplementedError, %(#{self.class} ##{__method__} method called before being registered)
      end
    end

    def process_block_given?
      defined? @process_block
    end
  end

  module DocumentProcessorDsl
    include ProcessorDsl

    def prefer
      option :position, :>>
    end
  end

  module SyntaxProcessorDsl
    include ProcessorDsl

    def named value
      # NOTE due to how processors get initialized, we must defer this assignment in some scenarios
      if Processor === self
        @name = value
      else
        option :name, value
      end
    end

    def content_model value
      option :content_model, value
    end
    alias parse_content_as content_model

    def positional_attributes *value
      option :positional_attrs, value.flatten
    end
    alias name_positional_attributes positional_attributes
    # NOTE positional_attrs alias is deprecated
    alias positional_attrs positional_attributes

    def default_attributes value
      option :default_attrs, value
    end
    # NOTE default_attrs alias is deprecated
    alias default_attrs default_attributes

    def resolve_attributes *args
      # NOTE assume true as default value; rewrap single-argument string or symbol
      if (args = args.fetch 0, true).respond_to? :to_sym
        args = [args]
      end unless args.size > 1
      case args
      when true
        option :positional_attrs, []
        option :default_attrs, {}
      when ::Array
        names, defaults = [], {}
        args.each do |arg|
          if (arg = arg.to_s).include? '='
            name, _, value = arg.partition '='
            if name.include? ':'
              idx, _, name = name.partition ':'
              idx = idx == '@' ? names.size : idx.to_i
              names[idx] = name
            end
            defaults[name] = value
          elsif arg.include? ':'
            idx, _, name = arg.partition ':'
            idx = idx == '@' ? names.size : idx.to_i
            names[idx] = name
          else
            names << arg
          end
        end
        option :positional_attrs, names.compact
        option :default_attrs, defaults
      when ::Hash
        names, defaults = [], {}
        args.each do |key, val|
          if (name = key.to_s).include? ':'
            idx, _, name = name.partition ':'
            idx = idx == '@' ? names.size : idx.to_i
            names[idx] = name
          end
          defaults[name] = val if val
        end
        option :positional_attrs, names.compact
        option :default_attrs, defaults
      else
        raise ::ArgumentError, %(unsupported attributes specification for macro: #{args.inspect})
      end
    end
    # NOTE resolves_attributes alias is deprecated
    alias resolves_attributes resolve_attributes
  end

  # Public: Preprocessors are run after the source text is split into lines and
  # normalized, but before parsing begins.
  #
  # Prior to invoking the preprocessor, Asciidoctor splits the source text into
  # lines and normalizes them. The normalize process strips trailing whitespace
  # and the end of line character sequence from each line.
  #
  # Asciidoctor passes the document and the document's Reader to the
  # {Processor#process} method of the Preprocessor instance. The Preprocessor
  # can modify the Reader as necessary and either return the same Reader (or
  # falsy, which is equivalent) or a reference to a substitute Reader.
  #
  # Preprocessor implementations must extend the Preprocessor class.
  class Preprocessor < Processor
    def process document, reader
      raise ::NotImplementedError, %(#{Preprocessor} subclass #{self.class} must implement the ##{__method__} method)
    end
  end
  Preprocessor::DSL = DocumentProcessorDsl

  # Public: TreeProcessors are run on the Document after the source has been
  # parsed into an abstract syntax tree (AST), as represented by the Document
  # object and its child Node objects (e.g., Section, Block, List, ListItem).
  #
  # Asciidoctor invokes the {Processor#process} method on an instance of each
  # registered TreeProcessor.
  #
  # TreeProcessor implementations must extend TreeProcessor.
  #--
  # QUESTION should the tree processor get invoked after parse header too?
  class TreeProcessor < Processor
    def process document
      raise ::NotImplementedError, %(#{TreeProcessor} subclass #{self.class} must implement the ##{__method__} method)
    end
  end
  TreeProcessor::DSL = DocumentProcessorDsl

  # Alias deprecated class name for backwards compatibility
  Treeprocessor = TreeProcessor

  # Public: Postprocessors are run after the document is converted, but before
  # it is written to the output stream.
  #
  # Asciidoctor passes a reference to the converted String to the {Processor#process}
  # method of each registered Postprocessor. The Preprocessor modifies the
  # String as necessary and returns the String replacement.
  #
  # The markup format in the String is determined by the backend used to convert
  # the Document. The backend and be looked up using the backend method on the
  # Document object, as well as various backend-related document attributes.
  #
  # TIP: Postprocessors can also be used to relocate assets needed by the published
  # document.
  #
  # Postprocessor implementations must Postprocessor.
  class Postprocessor < Processor
    def process document, output
      raise ::NotImplementedError, %(#{Postprocessor} subclass #{self.class} must implement the ##{__method__} method)
    end
  end
  Postprocessor::DSL = DocumentProcessorDsl

  # Public: IncludeProcessors are used to process `include::<target>[]`
  # directives in the source document.
  #
  # When Asciidoctor comes across a `include::<target>[]` directive in the
  # source document, it iterates through the IncludeProcessors and delegates
  # the work of reading the content to the first processor that identifies
  # itself as capable of handling that target.
  #
  # IncludeProcessor implementations must extend IncludeProcessor.
  #--
  # TODO add file extension or regexp as shortcut for handles? method
  class IncludeProcessor < Processor
    def process document, reader, target, attributes
      raise ::NotImplementedError, %(#{IncludeProcessor} subclass #{self.class} must implement the ##{__method__} method)
    end

    def handles? target
      true
    end
  end

  module IncludeProcessorDsl
    include DocumentProcessorDsl

    def handles? *args, &block
      if block_given?
        raise ::ArgumentError, %(wrong number of arguments (given #{args.size}, expected 0)) unless args.empty?
        @handles_block = block
      # TODO enable if we want to support passing proc or lambda as argument instead of block
      #elsif ::Proc === args[0]
      #  block = args.shift
      #  raise ::ArgumentError, %(wrong number of arguments (given #{args.size}, expected 0)) unless args.empty?
      #  @handles_block = block
      elsif defined? @handles_block
        @handles_block.call args[0]
      else
        true
      end
    end
  end
  IncludeProcessor::DSL = IncludeProcessorDsl

  # Public: DocinfoProcessors are used to add additional content to
  # the header and/or footer of the generated document.
  #
  # The placement of docinfo content is controlled by the converter.
  #
  # DocinfoProcessors implementations must extend DocinfoProcessor.
  # If a location is not specified, the DocinfoProcessor is assumed
  # to add content to the header.
  class DocinfoProcessor < Processor
    def initialize config = {}
      super config
      @config[:location] ||= :head
    end

    def process document
      raise ::NotImplementedError, %(#{DocinfoProcessor} subclass #{self.class} must implement the ##{__method__} method)
    end
  end

  module DocinfoProcessorDsl
    include DocumentProcessorDsl

    def at_location value
      option :location, value
    end
  end
  DocinfoProcessor::DSL = DocinfoProcessorDsl

  # Public: BlockProcessors are used to handle delimited blocks and paragraphs
  # that have a custom name.
  #
  # When Asciidoctor encounters a delimited block or paragraph with an
  # unrecognized name while parsing the document, it looks for a BlockProcessor
  # registered to handle this name and, if found, invokes its {Processor#process}
  # method to build a corresponding node in the document tree.
  #
  # AsciiDoc example:
  #
  #   [shout]
  #   Get a move on.
  #
  # Recognized options:
  #
  # * :named - The name of the block (required: true)
  # * :contexts - The blocks contexts on which this style can be used (default: [:paragraph, :open]
  # * :content_model - The structure of the content supported in this block (default: :compound)
  # * :positional_attrs - A list of attribute names used to map positional attributes (default: nil)
  # * :default_attrs - A hash of attribute names and values used to seed the attributes hash (default: nil)
  # * ...
  #
  # BlockProcessor implementations must extend BlockProcessor.
  class BlockProcessor < Processor
    attr_accessor :name

    def initialize name = nil, config = {}
      super config
      @name = name || @config[:name]
      # assign fallbacks
      case @config[:contexts]
      when ::NilClass
        @config[:contexts] ||= [:open, :paragraph].to_set
      when ::Symbol
        @config[:contexts] = [@config[:contexts]].to_set
      else
        @config[:contexts] = @config[:contexts].to_set
      end
      # QUESTION should the default content model be raw??
      @config[:content_model] ||= :compound
    end

    def process parent, reader, attributes
      raise ::NotImplementedError, %(#{BlockProcessor} subclass #{self.class} must implement the ##{__method__} method)
    end
  end

  module BlockProcessorDsl
    include SyntaxProcessorDsl

    def contexts *value
      option :contexts, value.flatten.to_set
    end
    alias on_contexts contexts
    alias on_context contexts
    alias bind_to contexts
  end
  BlockProcessor::DSL = BlockProcessorDsl

  class MacroProcessor < Processor
    attr_accessor :name

    def initialize name = nil, config = {}
      super config
      @name = name || @config[:name]
      @config[:content_model] ||= :attributes
    end

    def process parent, target, attributes
      raise ::NotImplementedError, %(#{MacroProcessor} subclass #{self.class} must implement the ##{__method__} method)
    end
  end

  module MacroProcessorDsl
    include SyntaxProcessorDsl

    def resolve_attributes *args
      if args.size == 1 && !args[0]
        option :content_model, :text
      else
        super
        option :content_model, :attributes
      end
    end
    # NOTE resolves_attributes alias is deprecated
    alias resolves_attributes resolve_attributes
  end

  # Public: BlockMacroProcessors are used to handle block macros that have a
  # custom name.
  #
  # BlockMacroProcessor implementations must extend BlockMacroProcessor.
  class BlockMacroProcessor < MacroProcessor
    def name
      raise ::ArgumentError, %(invalid name for block macro: #{@name}) unless MacroNameRx.match? @name.to_s
      @name
    end
  end
  BlockMacroProcessor::DSL = MacroProcessorDsl

  # Public: InlineMacroProcessors are used to handle block macros that have a
  # custom name.
  #
  # InlineMacroProcessor implementations must extend InlineMacroProcessor.
  #--
  # TODO break this out into different pattern types
  # for example, FullInlineMacro, ShortInlineMacro (no target) and other patterns
  # FIXME for inline passthrough, we need to have some way to specify the text as a passthrough
  class InlineMacroProcessor < MacroProcessor
    @@rx_cache = {}

    # Lookup the regexp option, resolving it first if necessary.
    # Once this method is called, the regexp is considered frozen.
    def regexp
      @config[:regexp] ||= resolve_regexp @name.to_s, @config[:format]
    end

    def resolve_regexp name, format
      raise ::ArgumentError, %(invalid name for inline macro: #{name}) unless MacroNameRx.match? name
      @@rx_cache[[name, format]] ||= /\\?#{name}:#{format == :short ? '(){0}' : '(\S+?)'}\[(|#{CC_ANY}*?[^\\])\]/
    end
  end

  module InlineMacroProcessorDsl
    include MacroProcessorDsl

    def format value
      option :format, value
    end
    alias match_format format
    # NOTE using_format alias is deprecated
    alias using_format format

    def match value
      option :regexp, value
    end
  end
  InlineMacroProcessor::DSL = InlineMacroProcessorDsl

  # Public: Extension is a proxy object for an extension implementation such as
  # a processor. It allows the preparation of the extension instance to be
  # separated from its usage to provide consistency between different
  # interfaces and avoid tight coupling with the extension type.
  #
  # The proxy encapsulates the extension kind (e.g., :block), its config Hash
  # and the extension instance. This Proxy is what gets stored in the extension
  # registry when activated.
  #--
  # QUESTION call this ExtensionInfo?
  class Extension
    attr_reader :kind
    attr_reader :config
    attr_reader :instance

    def initialize kind, instance, config
      @kind = kind
      @instance = instance
      @config = config
    end
  end

  # Public: A specialization of the Extension proxy that additionally stores a
  # reference to the {Processor#process} method. By storing this reference, its
  # possible to accomodate both concrete extension implementations and Procs.
  class ProcessorExtension < Extension
    attr_reader :process_method

    def initialize kind, instance, process_method = nil
      super kind, instance, instance.config
      @process_method = process_method || (instance.method :process)
    end
  end

  # Public: A Group is used to register one or more extensions with the Registry.
  #
  # The Group should be subclassed and registered with the Registry either by
  # invoking the {Group.register} method or passing the subclass to the
  # {Extensions.register} method. Extensions are registered with the Registry
  # inside the {Group#activate} method.
  class Group
    class << self
      def register name = nil
        Extensions.register name, self
      end
    end

    def activate registry
      raise ::NotImplementedError
    end
  end

  # Public: The primary entry point into the extension system.
  #
  # Registry holds the extensions which have been registered and activated, has
  # methods for registering or defining a processor and looks up extensions
  # stored in the registry during parsing.
  class Registry
    # Public: Returns the {Asciidoctor::Document} on which the extensions in this registry are being used.
    attr_reader :document

    # Public: Returns the Hash of {Group} classes, instances, and/or Procs that have been registered with this registry.
    attr_reader :groups

    def initialize groups = {}
      @groups = groups
      @preprocessor_extensions = @tree_processor_extensions = @postprocessor_extensions = @include_processor_extensions = @docinfo_processor_extensions = @block_extensions = @block_macro_extensions = @inline_macro_extensions = nil
      @document = nil
    end

    # Public: Activates all the global extension {Group}s and the extension {Group}s
    # associated with this registry.
    #
    # document - the {Asciidoctor::Document} on which the extensions are to be used.
    #
    # Returns the instance of this [Registry].
    def activate document
      @document = document
      unless (ext_groups = Extensions.groups.values + @groups.values).empty?
        ext_groups.each do |group|
          case group
          when ::Proc
            case group.arity
            when 0, -1
              instance_exec(&group)
            when 1
              group.call self
            end
          when ::Class
            group.new.activate self
          else
            group.activate self
          end
        end
      end
      self
    end

    # Public: Registers a {Preprocessor} with the extension registry to process
    # the AsciiDoc source before parsing begins.
    #
    # The Preprocessor may be one of four types:
    #
    # * A Preprocessor subclass
    # * An instance of a Preprocessor subclass
    # * The String name of a Preprocessor subclass
    # * A method block (i.e., Proc) that conforms to the Preprocessor contract
    #
    # Unless the Preprocessor is passed as the method block, it must be the
    # first argument to this method.
    #
    # Examples
    #
    #   # as a Preprocessor subclass
    #   preprocessor FrontMatterPreprocessor
    #
    #   # as an instance of a Preprocessor subclass
    #   preprocessor FrontMatterPreprocessor.new
    #
    #   # as a name of a Preprocessor subclass
    #   preprocessor 'FrontMatterPreprocessor'
    #
    #   # as a method block
    #   preprocessor do
    #     process do |doc, reader|
    #       ...
    #     end
    #   end
    #
    # Returns the [Extension] stored in the registry that proxies the
    # instance of this Preprocessor.
    def preprocessor *args, &block
      add_document_processor :preprocessor, args, &block
    end

    # Public: Checks whether any {Preprocessor} extensions have been registered.
    #
    # Returns a [Boolean] indicating whether any Preprocessor extensions are registered.
    def preprocessors?
      !!@preprocessor_extensions
    end

    # Public: Retrieves the {Extension} proxy objects for all
    # Preprocessor instances in this registry.
    #
    # Returns an [Array] of Extension proxy objects.
    def preprocessors
      @preprocessor_extensions
    end

    # Public: Registers a {TreeProcessor} with the extension registry to process
    # the AsciiDoc source after parsing is complete.
    #
    # The TreeProcessor may be one of four types:
    #
    # * A TreeProcessor subclass
    # * An instance of a TreeProcessor subclass
    # * The String name of a TreeProcessor subclass
    # * A method block (i.e., Proc) that conforms to the TreeProcessor contract
    #
    # Unless the TreeProcessor is passed as the method block, it must be the
    # first argument to this method.
    #
    # Examples
    #
    #   # as a TreeProcessor subclass
    #   tree_processor ShellTreeProcessor
    #
    #   # as an instance of a TreeProcessor subclass
    #   tree_processor ShellTreeProcessor.new
    #
    #   # as a name of a TreeProcessor subclass
    #   tree_processor 'ShellTreeProcessor'
    #
    #   # as a method block
    #   tree_processor do
    #     process do |document|
    #       ...
    #     end
    #   end
    #
    # Returns the [Extension] stored in the registry that proxies the
    # instance of this TreeProcessor.
    def tree_processor *args, &block
      add_document_processor :tree_processor, args, &block
    end

    # Public: Checks whether any {TreeProcessor} extensions have been registered.
    #
    # Returns a [Boolean] indicating whether any TreeProcessor extensions are registered.
    def tree_processors?
      !!@tree_processor_extensions
    end

    # Public: Retrieves the {Extension} proxy objects for all
    # TreeProcessor instances in this registry.
    #
    # Returns an [Array] of Extension proxy objects.
    def tree_processors
      @tree_processor_extensions
    end

    # Alias deprecated methods for backwards compatibility
    alias treeprocessor tree_processor
    alias treeprocessors? tree_processors?
    alias treeprocessors tree_processors

    # Public: Registers a {Postprocessor} with the extension registry to process
    # the output after conversion is complete.
    #
    # The Postprocessor may be one of four types:
    #
    # * A Postprocessor subclass
    # * An instance of a Postprocessor subclass
    # * The String name of a Postprocessor subclass
    # * A method block (i.e., Proc) that conforms to the Postprocessor contract
    #
    # Unless the Postprocessor is passed as the method block, it must be the
    # first argument to this method.
    #
    # Examples
    #
    #   # as a Postprocessor subclass
    #   postprocessor AnalyticsPostprocessor
    #
    #   # as an instance of a Postprocessor subclass
    #   postprocessor AnalyticsPostprocessor.new
    #
    #   # as a name of a Postprocessor subclass
    #   postprocessor 'AnalyticsPostprocessor'
    #
    #   # as a method block
    #   postprocessor do
    #     process do |document, output|
    #       ...
    #     end
    #   end
    #
    # Returns the [Extension] stored in the registry that proxies the
    # instance of this Postprocessor.
    def postprocessor *args, &block
      add_document_processor :postprocessor, args, &block
    end

    # Public: Checks whether any {Postprocessor} extensions have been registered.
    #
    # Returns a [Boolean] indicating whether any Postprocessor extensions are registered.
    def postprocessors?
      !!@postprocessor_extensions
    end

    # Public: Retrieves the {Extension} proxy objects for all
    # Postprocessor instances in this registry.
    #
    # Returns an [Array] of Extension proxy objects.
    def postprocessors
      @postprocessor_extensions
    end

    # Public: Registers an {IncludeProcessor} with the extension registry to have
    # a shot at handling the include directive.
    #
    # The IncludeProcessor may be one of four types:
    #
    # * A IncludeProcessor subclass
    # * An instance of a IncludeProcessor subclass
    # * The String name of a IncludeProcessor subclass
    # * A method block (i.e., Proc) that conforms to the IncludeProcessor contract
    #
    # Unless the IncludeProcessor is passed as the method block, it must be the
    # first argument to this method.
    #
    # Examples
    #
    #   # as an IncludeProcessor subclass
    #   include_processor GitIncludeProcessor
    #
    #   # as an instance of a Postprocessor subclass
    #   include_processor GitIncludeProcessor.new
    #
    #   # as a name of a Postprocessor subclass
    #   include_processor 'GitIncludeProcessor'
    #
    #   # as a method block
    #   include_processor do
    #     process do |document, output|
    #       ...
    #     end
    #   end
    #
    # Returns the [Extension] stored in the registry that proxies the
    # instance of this IncludeProcessor.
    def include_processor *args, &block
      add_document_processor :include_processor, args, &block
    end

    # Public: Checks whether any {IncludeProcessor} extensions have been registered.
    #
    # Returns a [Boolean] indicating whether any IncludeProcessor extensions are registered.
    def include_processors?
      !!@include_processor_extensions
    end

    # Public: Retrieves the {Extension} proxy objects for all the
    # IncludeProcessor instances stored in this registry.
    #
    # Returns an [Array] of Extension proxy objects.
    def include_processors
      @include_processor_extensions
    end

    # Public: Registers an {DocinfoProcessor} with the extension registry to
    # add additionnal docinfo to the document.
    #
    # The DocinfoProcessor may be one of four types:
    #
    # * A DocinfoProcessor subclass
    # * An instance of a DocinfoProcessor subclass
    # * The String name of a DocinfoProcessor subclass
    # * A method block (i.e., Proc) that conforms to the DocinfoProcessor contract
    #
    # Unless the DocinfoProcessor is passed as the method block, it must be the
    # first argument to this method.
    #
    # Examples
    #
    #   # as an DocinfoProcessor subclass
    #   docinfo_processor MetaRobotsDocinfoProcessor
    #
    #   # as an instance of a DocinfoProcessor subclass with an explicit location
    #   docinfo_processor JQueryDocinfoProcessor.new, location: :footer
    #
    #   # as a name of a DocinfoProcessor subclass
    #   docinfo_processor 'MetaRobotsDocinfoProcessor'
    #
    #   # as a method block
    #   docinfo_processor do
    #     process do |doc|
    #       at_location :footer
    #       'footer content'
    #     end
    #   end
    #
    # Returns the [Extension] stored in the registry that proxies the
    # instance of this DocinfoProcessor.
    def docinfo_processor *args, &block
      add_document_processor :docinfo_processor, args, &block
    end

    # Public: Checks whether any {DocinfoProcessor} extensions have been registered.
    #
    # location - A Symbol for selecting docinfo extensions at a given location (:head or :footer) (default: nil)
    #
    # Returns a [Boolean] indicating whether any DocinfoProcessor extensions are registered.
    def docinfo_processors? location = nil
      if @docinfo_processor_extensions
        if location
          @docinfo_processor_extensions.any? {|ext| ext.config[:location] == location }
        else
          true
        end
      else
        false
      end
    end

    # Public: Retrieves the {Extension} proxy objects for all the
    # DocinfoProcessor instances stored in this registry.
    #
    # location - A Symbol for selecting docinfo extensions at a given location (:head or :footer) (default: nil)
    #
    # Returns an [Array] of Extension proxy objects.
    def docinfo_processors location = nil
      if @docinfo_processor_extensions
        if location
          @docinfo_processor_extensions.select {|ext| ext.config[:location] == location }
        else
          @docinfo_processor_extensions
        end
      else
        nil
      end
    end

    # Public: Registers a {BlockProcessor} with the extension registry to
    # process the block content (i.e., delimited block or paragraph) in the
    # AsciiDoc source annotated with the specified block name (i.e., style).
    #
    # The BlockProcessor may be one of four types:
    #
    # * A BlockProcessor subclass
    # * An instance of a BlockProcessor subclass
    # * The String name of a BlockProcessor subclass
    # * A method block (i.e., Proc) that conforms to the BlockProcessor contract
    #
    # Unless the BlockProcessor is passed as the method block, it must be the
    # first argument to this method. The second argument is the name (coersed
    # to a Symbol) of the AsciiDoc block content (i.e., delimited block or
    # paragraph) that this processor is registered to handle. If a block name
    # is not passed as an argument, it gets read from the name property of the
    # BlockProcessor instance. If a name still cannot be determined, an error
    # is raised.
    #
    # Examples
    #
    #   # as a BlockProcessor subclass
    #   block ShoutBlock
    #
    #   # as a BlockProcessor subclass with an explicit block name
    #   block ShoutBlock, :shout
    #
    #   # as an instance of a BlockProcessor subclass
    #   block ShoutBlock.new
    #
    #   # as an instance of a BlockProcessor subclass with an explicit block name
    #   block ShoutBlock.new, :shout
    #
    #   # as a name of a BlockProcessor subclass
    #   block 'ShoutBlock'
    #
    #   # as a name of a BlockProcessor subclass with an explicit block name
    #   block 'ShoutBlock', :shout
    #
    #   # as a method block
    #   block do
    #     named :shout
    #     process do |parent, reader, attrs|
    #       ...
    #     end
    #   end
    #
    #   # as a method block with an explicit block name
    #   block :shout do
    #     process do |parent, reader, attrs|
    #       ...
    #     end
    #   end
    #
    # Returns an instance of the [Extension] proxy object that is stored in the
    # registry and manages the instance of this BlockProcessor.
    def block *args, &block
      add_syntax_processor :block, args, &block
    end

    # Public: Checks whether any {BlockProcessor} extensions have been registered.
    #
    # Returns a [Boolean] indicating whether any BlockProcessor extensions are registered.
    def blocks?
      !!@block_extensions
    end

    # Public: Checks whether any {BlockProcessor} extensions are registered to
    # handle the specified block name appearing on the specified context.
    #
    # Returns the [Extension] proxy object for the BlockProcessor that matches
    # the block name and context or false if no match is found.
    def registered_for_block? name, context
      if (ext = @block_extensions[name.to_sym])
        (ext.config[:contexts].include? context) ? ext : false
      else
        false
      end
    end

    # Public: Retrieves the {Extension} proxy object for the BlockProcessor registered
    # to handle block content with the name.
    #
    # name - the String or Symbol (coersed to a Symbol) macro name
    #
    # Returns the [Extension] object stored in the registry that proxies the
    # corresponding BlockProcessor or nil if a match is not found.
    def find_block_extension name
      @block_extensions[name.to_sym]
    end

    # Public: Registers a {BlockMacroProcessor} with the extension registry to
    # process a block macro with the specified name.
    #
    # The BlockMacroProcessor may be one of four types:
    #
    # * A BlockMacroProcessor subclass
    # * An instance of a BlockMacroProcessor subclass
    # * The String name of a BlockMacroProcessor subclass
    # * A method block (i.e., Proc) that conforms to the BlockMacroProcessor contract
    #
    # Unless the BlockMacroProcessor is passed as the method block, it must be
    # the first argument to this method. The second argument is the name
    # (coersed to a Symbol) of the AsciiDoc block macro that this processor is
    # registered to handle. If a block macro name is not passed as an argument,
    # it gets read from the name property of the BlockMacroProcessor instance.
    # If a name still cannot be determined, an error is raised.
    #
    # Examples
    #
    #   # as a BlockMacroProcessor subclass
    #   block_macro GistBlockMacro
    #
    #   # as a BlockMacroProcessor subclass with an explicit macro name
    #   block_macro GistBlockMacro, :gist
    #
    #   # as an instance of a BlockMacroProcessor subclass
    #   block_macro GistBlockMacro.new
    #
    #   # as an instance of a BlockMacroProcessor subclass with an explicit macro name
    #   block_macro GistBlockMacro.new, :gist
    #
    #   # as a name of a BlockMacroProcessor subclass
    #   block_macro 'GistBlockMacro'
    #
    #   # as a name of a BlockMacroProcessor subclass with an explicit macro name
    #   block_macro 'GistBlockMacro', :gist
    #
    #   # as a method block
    #   block_macro do
    #     named :gist
    #     process do |parent, target, attrs|
    #       ...
    #     end
    #   end
    #
    #   # as a method block with an explicit macro name
    #   block_macro :gist do
    #     process do |parent, target, attrs|
    #       ...
    #     end
    #   end
    #
    # Returns an instance of the [Extension] proxy object that is stored in the
    # registry and manages the instance of this BlockMacroProcessor.
    def block_macro *args, &block
      add_syntax_processor :block_macro, args, &block
    end

    # Public: Checks whether any {BlockMacroProcessor} extensions have been registered.
    #
    # Returns a [Boolean] indicating whether any BlockMacroProcessor extensions are registered.
    def block_macros?
      !!@block_macro_extensions
    end

    # Public: Checks whether any {BlockMacroProcessor} extensions are registered to
    # handle the block macro with the specified name.
    #
    # name - the String or Symbol (coersed to a Symbol) macro name
    #
    # Returns the [Extension] proxy object for the BlockMacroProcessor that matches
    # the macro name or false if no match is found.
    #--
    # TODO only allow blank target if format is :short
    def registered_for_block_macro? name
      (ext = @block_macro_extensions[name.to_sym]) ? ext : false
    end

    # Public: Retrieves the {Extension} proxy object for the BlockMacroProcessor registered
    # to handle a block macro with the specified name.
    #
    # name - the String or Symbol (coersed to a Symbol) macro name
    #
    # Returns the [Extension] object stored in the registry that proxies the
    # cooresponding BlockMacroProcessor or nil if a match is not found.
    def find_block_macro_extension name
      @block_macro_extensions[name.to_sym]
    end

    # Public: Registers a {InlineMacroProcessor} with the extension registry to
    # process an inline macro with the specified name.
    #
    # The InlineMacroProcessor may be one of four types:
    #
    # * An InlineMacroProcessor subclass
    # * An instance of an InlineMacroProcessor subclass
    # * The String name of an InlineMacroProcessor subclass
    # * A method block (i.e., Proc) that conforms to the InlineMacroProcessor contract
    #
    # Unless the InlineMacroProcessor is passed as the method block, it must be
    # the first argument to this method. The second argument is the name
    # (coersed to a Symbol) of the AsciiDoc block macro that this processor is
    # registered to handle. If a block macro name is not passed as an argument,
    # it gets read from the name property of the InlineMacroProcessor instance.
    # If a name still cannot be determined, an error is raised.
    #
    # Examples
    #
    #   # as an InlineMacroProcessor subclass
    #   inline_macro ChromeInlineMacro
    #
    #   # as an InlineMacroProcessor subclass with an explicit macro name
    #   inline_macro ChromeInlineMacro, :chrome
    #
    #   # as an instance of an InlineMacroProcessor subclass
    #   inline_macro ChromeInlineMacro.new
    #
    #   # as an instance of an InlineMacroProcessor subclass with an explicit macro name
    #   inline_macro ChromeInlineMacro.new, :chrome
    #
    #   # as a name of an InlineMacroProcessor subclass
    #   inline_macro 'ChromeInlineMacro'
    #
    #   # as a name of an InlineMacroProcessor subclass with an explicit macro name
    #   inline_macro 'ChromeInlineMacro', :chrome
    #
    #   # as a method block
    #   inline_macro do
    #     named :chrome
    #     process do |parent, target, attrs|
    #       ...
    #     end
    #   end
    #
    #   # as a method block with an explicit macro name
    #   inline_macro :chrome do
    #     process do |parent, target, attrs|
    #       ...
    #     end
    #   end
    #
    # Returns an instance of the [Extension] proxy object that is stored in the
    # registry and manages the instance of this InlineMacroProcessor.
    def inline_macro *args, &block
      add_syntax_processor :inline_macro, args, &block
    end

    # Public: Checks whether any {InlineMacroProcessor} extensions have been registered.
    #
    # Returns a [Boolean] indicating whether any IncludeMacroProcessor extensions are registered.
    def inline_macros?
      !!@inline_macro_extensions
    end

    # Public: Checks whether any {InlineMacroProcessor} extensions are registered to
    # handle the inline macro with the specified name.
    #
    # name - the String or Symbol (coersed to a Symbol) macro name
    #
    # Returns the [Extension] proxy object for the InlineMacroProcessor that matches
    # the macro name or false if no match is found.
    def registered_for_inline_macro? name
      (ext = @inline_macro_extensions[name.to_sym]) ? ext : false
    end

    # Public: Retrieves the {Extension} proxy object for the InlineMacroProcessor registered
    # to handle an inline macro with the specified name.
    #
    # name - the String or Symbol (coersed to a Symbol) macro name
    #
    # Returns the [Extension] object stored in the registry that proxies the
    # cooresponding InlineMacroProcessor or nil if a match is not found.
    def find_inline_macro_extension name
      @inline_macro_extensions[name.to_sym]
    end

    # Public: Retrieves the {Extension} proxy objects for all
    # InlineMacroProcessor instances in this registry.
    #
    # Returns an [Array] of Extension proxy objects.
    def inline_macros
      @inline_macro_extensions.values
    end

    # Public: Inserts the document processor {Extension} instance as the first
    # processor of its kind in the extension registry.
    #
    # Examples
    #
    #   prefer :include_processor do
    #     process do |document, reader, target, attrs|
    #       ...
    #     end
    #   end
    #
    # Returns the [Extension] stored in the registry that proxies the instance
    # of this processor.
    def prefer *args, &block
      extension = ProcessorExtension === (arg0 = args.shift) ? arg0 : (send arg0, *args, &block)
      extensions_store = instance_variable_get(%(@#{extension.kind}_extensions).to_sym)
      extensions_store.unshift extensions_store.delete extension
      extension
    end

    private

    def add_document_processor kind, args, &block
      kind_name = kind.to_s.tr '_', ' '
      kind_class_symbol = kind_name.split.map {|it| it.capitalize }.join.to_sym
      kind_class = Extensions.const_get kind_class_symbol, false
      kind_java_class = (defined? ::AsciidoctorJ) ? (::AsciidoctorJ::Extensions.const_get kind_class_symbol, false) : nil
      kind_store = instance_variable_get(%(@#{kind}_extensions).to_sym) || instance_variable_set(%(@#{kind}_extensions).to_sym, [])
      # style 1: specified as block
      extension = if block_given?
        config = resolve_args args, 1
        (processor = kind_class.new config).singleton_class.enable_dsl
        if block.arity == 0
          processor.instance_exec(&block)
        else
          yield processor
        end
        unless processor.process_block_given?
          raise ::ArgumentError, %(No block specified to process #{kind_name} extension at #{block.source_location})
        end
        processor.freeze
        ProcessorExtension.new kind, processor
      else
        processor, config = resolve_args args, 2
        # style 2: specified as Class or String class name
        if (processor_class = Helpers.resolve_class processor)
          unless processor_class < kind_class || (kind_java_class && processor_class < kind_java_class)
            raise ::ArgumentError, %(Invalid type for #{kind_name} extension: #{processor})
          end
          processor_instance = processor_class.new config
          processor_instance.freeze
          ProcessorExtension.new kind, processor_instance
        # style 3: specified as instance
        elsif kind_class === processor || (kind_java_class && kind_java_class === processor)
          processor.update_config config
          processor.freeze
          ProcessorExtension.new kind, processor
        else
          raise ::ArgumentError, %(Invalid arguments specified for registering #{kind_name} extension: #{args})
        end
      end

      extension.config[:position] == :>> ? (kind_store.unshift extension) : (kind_store << extension)
      extension
    end

    def add_syntax_processor kind, args, &block
      kind_name = kind.to_s.tr '_', ' '
      kind_class_symbol = (kind_name.split.map {|it| it.capitalize } << 'Processor').join.to_sym
      kind_class = Extensions.const_get kind_class_symbol, false
      kind_java_class = (defined? ::AsciidoctorJ) ? (::AsciidoctorJ::Extensions.const_get kind_class_symbol, false) : nil
      kind_store = instance_variable_get(%(@#{kind}_extensions).to_sym) || instance_variable_set(%(@#{kind}_extensions).to_sym, {})
      # style 1: specified as block
      if block_given?
        name, config = resolve_args args, 2
        (processor = kind_class.new (as_symbol name), config).singleton_class.enable_dsl
        if block.arity == 0
          processor.instance_exec(&block)
        else
          yield processor
        end
        unless (name = as_symbol processor.name)
          raise ::ArgumentError, %(No name specified for #{kind_name} extension at #{block.source_location})
        end
        unless processor.process_block_given?
          raise ::NoMethodError, %(No block specified to process #{kind_name} extension at #{block.source_location})
        end
        processor.freeze
        kind_store[name] = ProcessorExtension.new kind, processor
      else
        processor, name, config = resolve_args args, 3
        # style 2: specified as Class or String class name
        if (processor_class = Helpers.resolve_class processor)
          unless processor_class < kind_class || (kind_java_class && processor_class < kind_java_class)
            raise ::ArgumentError, %(Class specified for #{kind_name} extension does not inherit from #{kind_class}: #{processor})
          end
          processor_instance = processor_class.new as_symbol(name), config
          unless (name = as_symbol processor_instance.name)
            raise ::ArgumentError, %(No name specified for #{kind_name} extension: #{processor})
          end
          processor_instance.freeze
          kind_store[name] = ProcessorExtension.new kind, processor_instance
        # style 3: specified as instance
        elsif kind_class === processor || (kind_java_class && kind_java_class === processor)
          processor.update_config config
          # TODO need a test for this override!
          unless (name = name ? (processor.name = as_symbol name) : (as_symbol processor.name))
            raise ::ArgumentError, %(No name specified for #{kind_name} extension: #{processor})
          end
          processor.freeze
          kind_store[name] = ProcessorExtension.new kind, processor
        else
          raise ::ArgumentError, %(Invalid arguments specified for registering #{kind_name} extension: #{args})
        end
      end
    end

    def resolve_args args, expect
      opts = ::Hash === args[-1] ? args.pop : {}
      return opts if expect == 1
      if (missing = expect - 1 - args.size) > 0
        args += (::Array.new missing)
      elsif missing < 0
        args.pop(-missing)
      end
      args << opts
      args
    end

    def as_symbol name
      name ? name.to_sym : nil
    end
  end

  class << self
    def generate_name
      %(extgrp#{next_auto_id})
    end

    def next_auto_id
      @auto_id ||= -1
      @auto_id += 1
    end

    def groups
      @groups ||= {}
    end

    def create name = nil, &block
      if block_given?
        Registry.new (name || generate_name) => block
      else
        Registry.new
      end
    end

    # Public: Registers an extension Group that subsequently registers a
    # collection of extensions.
    #
    # Registers the extension Group specified under the given name. If a name is
    # not given, one is calculated by appending the next value in a 0-based
    # index to the string "extgrp". For instance, the first unnamed extension
    # group to be registered is assigned the name "extgrp0" if a name is not
    # specified.
    #
    # The names are not yet used, but are intended for selectively activating
    # extensions in the future.
    #
    # If the extension group argument is a String or a Symbol, it gets resolved
    # to a Class before being registered.
    #
    # name    - The name under which this extension group is registered (optional, default: nil)
    # group   - A block (Proc), a Class, a String or Symbol name of a Class or
    #           an Object instance of a Class.
    #
    # Examples
    #
    #   Asciidoctor::Extensions.register UmlExtensions
    #
    #   Asciidoctor::Extensions.register :uml, UmlExtensions
    #
    #   Asciidoctor::Extensions.register do
    #     block_processor :plantuml, PlantUmlBlock
    #   end
    #
    #   Asciidoctor::Extensions.register :uml do
    #     block_processor :plantuml, PlantUmlBlock
    #   end
    #
    # Returns the [Proc, Class or Object] instance, matching the type passed to this method.
    def register *args, &block
      argc = args.size
      if block_given?
        resolved_group = block
      elsif (group = args.pop)
        # QUESTION should we instantiate the group class here or defer until activation??
        resolved_group = (Helpers.resolve_class group) || group
      else
        raise ::ArgumentError, %(Extension group to register not specified)
      end
      name = args.pop || generate_name
      unless args.empty?
        raise ::ArgumentError, %(Wrong number of arguments (#{argc} for 1..2))
      end
      groups[name.to_sym] = resolved_group
    end

    # Public: Unregister all statically-registered extension groups.
    #
    # Returns nothing
    def unregister_all
      @groups = {}
      nil
    end

    # Public: Unregister statically-registered extension groups by name.
    #
    # names - one or more Symbol or String group names to unregister
    #
    # Returns nothing
    def unregister *names
      names.each {|group| @groups.delete group.to_sym }
      nil
    end
  end
end
end
