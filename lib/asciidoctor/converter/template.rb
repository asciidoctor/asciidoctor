# encoding: UTF-8
module Asciidoctor
  # A {Converter} implementation that uses templates composed in template
  # languages supported by {https://github.com/rtomayko/tilt Tilt} to convert
  # {AbstractNode} objects from a parsed AsciiDoc document tree to the backend
  # format.
  #
  # The converter scans the specified directories for template files that are
  # supported by Tilt. If an engine name (e.g., "slim") is specified in the
  # options Hash passed to the constructor, the scan is restricted to template
  # files that have a matching extension (e.g., ".slim"). The scanner trims any
  # extensions from the basename of the file and uses the resulting name as the
  # key under which to store the template. When the {Converter#convert} method
  # is invoked, the transform argument is used to select the template from this
  # table and use it to convert the node.
  #
  # For example, the template file "path/to/templates/paragraph.html.slim" will
  # be registered as the "paragraph" transform. The template is then used to
  # convert a paragraph {Block} object from the parsed AsciiDoc tree to an HTML
  # backend format (e.g., "html5").
  #
  # As an optimization, scan results and templates are cached for the lifetime
  # of the Ruby process. If the {https://rubygems.org/gems/thread_safe
  # thread_safe} gem is installed, these caches are guaranteed to be thread
  # safe. If this gem is not present, there is no such guarantee and a warning
  # will be issued.
  class Converter::TemplateConverter < Converter::Base
    DEFAULT_ENGINE_OPTIONS = {
      :erb =>  { :trim => '<' },
      # TODO line 466 of haml/compiler.rb sorts the attributes; file an issue to make this configurable
      # NOTE AsciiDoc syntax expects HTML/XML output to use double quotes around attribute values
      :haml => { :format => :xhtml, :attr_wrapper => '"', :escape_attrs => false, :ugly => true },
      :slim => { :disable_escape => true, :sort_attrs => false, :pretty => false }
    }

    # QUESTION are we handling how we load the thread_safe support correctly?
    begin
      require 'thread_safe' unless defined? ::ThreadSafe
      @caches = { :scans => ::ThreadSafe::Cache.new, :templates => ::ThreadSafe::Cache.new }
    rescue ::LoadError
      @caches = { :scans => {}, :templates => {} }
    end

    def self.caches
      @caches
    end

    def self.clear_caches
      @caches[:scans].clear if @caches[:scans]
      @caches[:templates].clear if @caches[:templates]
    end

    def initialize backend, template_dirs, opts = {}
      Helpers.require_library 'tilt' unless defined? ::Tilt
      @backend = backend
      @templates = {}
      @template_dirs = template_dirs
      @eruby = opts[:eruby]
      @safe = opts[:safe]
      @active_engines = {}
      @engine = opts[:template_engine]
      @engine_options = DEFAULT_ENGINE_OPTIONS.inject({}) do |accum, (engine, default_opts)|
        accum[engine] = default_opts.dup
        accum
      end
      if opts[:htmlsyntax] == 'html'
        @engine_options[:haml][:format] = :html5
        @engine_options[:slim][:format] = :html
      end
      @engine_options[:slim][:include_dirs] = template_dirs.reverse.map {|dir| ::File.expand_path dir }
      if (overrides = opts[:template_engine_options])
        overrides.each do |engine, override_opts|
          (@engine_options[engine] ||= {}).update override_opts
        end
      end
      case opts[:template_cache]
      when true
        logger.warn 'gem \'thread_safe\' is not installed. This gem is recommended when using the built-in template cache.' unless defined? ::ThreadSafe
        @caches = self.class.caches
      when ::Hash
        @caches = opts[:template_cache]
      else
        @caches = {} # the empty Hash effectively disables caching
      end
      scan
      #create_handlers
    end

=begin
    # Public: Called when this converter is added to a composite converter.
    def composed parent
      # TODO set the backend info determined during the scan
    end
=end

    # Internal: Scans the template directories specified in the constructor for Tilt-supported
    # templates, loads the templates and stores the in a Hash that is accessible via the
    # {TemplateConverter#templates} method.
    #
    # Returns nothing
    def scan
      path_resolver = PathResolver.new
      backend = @backend
      engine = @engine
      @template_dirs.each do |template_dir|
        # FIXME need to think about safe mode restrictions here
        next unless ::File.directory?(template_dir = (path_resolver.system_path template_dir))

        if engine
          file_pattern = %(*.#{engine})
          # example: templates/haml
          if ::File.directory?(engine_dir = %(#{template_dir}/#{engine}))
            template_dir = engine_dir
          end
        else
          # NOTE last matching template wins for template name if no engine is given
          file_pattern = '*'
        end

        # example: templates/html5 (engine not set) or templates/haml/html5 (engine set)
        if ::File.directory?(backend_dir = %(#{template_dir}/#{backend}))
          template_dir = backend_dir
        end

        pattern = %(#{template_dir}/#{file_pattern})

        if (scan_cache = @caches[:scans])
          template_cache = @caches[:templates]
          unless (templates = scan_cache[pattern])
            templates = (scan_cache[pattern] = (scan_dir template_dir, pattern, template_cache))
          end
          templates.each do |name, template|
            @templates[name] = template_cache[template.file] = template
          end
        else
          @templates.update scan_dir(template_dir, pattern, @caches[:templates])
        end
        nil
      end
    end

=begin
    # Internal: Creates convert methods (e.g., inline_anchor) that delegate to the discovered templates.
    #
    # Returns nothing
    def create_handlers
      @templates.each do |name, template|
        create_handler name, template
      end
      nil
    end

    # Internal: Creates a convert method for the specified name that delegates to the specified template.
    #
    # Returns nothing
    def create_handler name, template
      metaclass = class << self; self; end
      if name == 'document'
        metaclass.send :define_method, name do |node|
          (template.render node).strip
        end
      else
        metaclass.send :define_method, name do |node|
          (template.render node).rstrip
        end
      end
    end
=end

    # Public: Convert an {AbstractNode} to the backend format using the named template.
    #
    # Looks for a template that matches the value of the
    # {AbstractNode#node_name} property if a template name is not specified.
    #
    # node          - the AbstractNode to convert
    # template_name - the String name of the template to use, or the value of
    #                 the node_name property on the node if a template name is
    #                 not specified. (optional, default: nil)
    # opts          - an optional Hash that is passed as local variables to the
    #                 template. (optional, default: {})
    #
    # Returns the [String] result from rendering the template
    def convert node, template_name = nil, opts = {}
      template_name ||= node.node_name
      unless (template = @templates[template_name])
        raise %(Could not find a custom template to handle transform: #{template_name})
      end

      # Slim doesn't include helpers in the template's execution scope (like HAML), so do it ourselves
      node.extend ::Slim::Helpers if (defined? ::Slim::Helpers) && (::Slim::Template === template)

      # NOTE opts become locals in the template
      if template_name == 'document'
        (template.render node, opts).strip
      else
        (template.render node, opts).rstrip
      end
    end

    # Public: Checks whether there is a Tilt template registered with the specified name.
    #
    # name - the String template name
    #
    # Returns a [Boolean] that indicates whether a Tilt template is registered for the
    # specified template name.
    def handles? name
      @templates.key? name
    end

    # Public: Retrieves the templates that this converter manages.
    #
    # Returns a [Hash] of Tilt template objects keyed by template name.
    def templates
      @templates.dup
    end

    # Public: Registers a Tilt template with this converter.
    #
    # name     - the String template name
    # template - the Tilt template object to register
    #
    # Returns the Tilt template object
    def register name, template
      @templates[name] = if (template_cache = @caches[:templates])
        template_cache[template.file] = template
      else
        template
      end
      #create_handler name, template
    end

    # Internal: Scan the specified directory for template files matching pattern and instantiate
    # a Tilt template for each matched file.
    #
    # Returns the scan result as a [Hash]
    def scan_dir template_dir, pattern, template_cache = nil
      result, helpers = {}, nil
      # Grab the files in the top level of the directory (do not recurse)
      ::Dir.glob(pattern).select {|match| ::File.file? match }.each do |file|
        if (basename = ::File.basename file) == 'helpers.rb'
          helpers = file
          next
        elsif (path_segments = basename.split '.').size < 2
          next
        end
        if (name = path_segments[0]) == 'block_ruler'
          name = 'thematic_break'
        elsif name.start_with? 'block_'
          name = name.slice 6, name.length
        end
        unless template_cache && (template = template_cache[file])
          template_class, extra_engine_options, extsym = ::Tilt, {}, path_segments[-1].to_sym
          case extsym
          when :slim
            unless @active_engines[extsym]
              # NOTE slim doesn't get automatically loaded by Tilt
              Helpers.require_library 'slim' unless defined? ::Slim
              # align safe mode of AsciiDoc embedded in Slim template with safe mode of current document
              # NOTE safe mode won't get updated if using template cache and changing safe mode
              (@engine_options[extsym][:asciidoc] ||= {})[:safe] ||= @safe if @safe && ::Slim::VERSION >= '3.0'
              # load include plugin when using Slim >= 2.1
              require 'slim/include' unless (defined? ::Slim::Include) || ::Slim::VERSION < '2.1'
              @active_engines[extsym] = true
            end
          when :haml
            unless @active_engines[extsym]
              Helpers.require_library 'haml' unless defined? ::Haml
              # NOTE Haml 5 dropped support for pretty printing
              @engine_options[extsym].delete :ugly if defined? ::Haml::TempleEngine
              @active_engines[extsym] = true
            end
          when :erb
            template_class, extra_engine_options = (@active_engines[extsym] ||= (load_eruby @eruby))
          when :rb
            next
          else
            next unless ::Tilt.registered? extsym.to_s
          end
          template = template_class.new file, 1, (@engine_options[extsym] ||= {}).merge(extra_engine_options)
        end
        result[name] = template
      end
      if helpers || ::File.file?(helpers = %(#{template_dir}/helpers.rb))
        require helpers
      end
      result
    end

    # Internal: Load the eRuby implementation
    #
    # name - the String name of the eRuby implementation
    #
    # Returns an [Array] containing the Tilt template Class for the eRuby implementation
    # and a Hash of additional options to pass to the initializer
    def load_eruby name
      if !name || name == 'erb'
        require 'erb' unless defined? ::ERB
        [::Tilt::ERBTemplate, {}]
      elsif name == 'erubis'
        Helpers.require_library 'erubis' unless defined? ::Erubis::FastEruby
        [::Tilt::ErubisTemplate, { :engine_class => ::Erubis::FastEruby }]
      else
        raise ::ArgumentError, %(Unknown ERB implementation: #{name})
      end
    end
  end
end
