module Asciidoctor
  # A {Converter} implementation that uses templates composed in template
  # languages supported by {https://github.com/rtomayko/tilt Tilt} to convert
  # {AbstractNode} objects from a parsed AsciiDoc document tree to the backend
  # format.
  #
  # The converter scans the provided directories for template files that are
  # supported by Tilt. If an engine name (e.g., "slim") is specified in the
  # options Hash passed to the constructor, the scan is limited to template
  # files that have a matching extension (e.g., ".slim"). The scanner trims any
  # extensions from the basename of the file and uses the resulting name as the
  # key under which to store the template. When the {Converter#convert} method
  # is invoked, the transform argument is used to select the template from this
  # table and use it to convert the node.
  #
  # For example, the template file "path/to/templates/paragraph.html.slim" will
  # be registered as the "paragraph" transform. The template would then be used
  # to convert a paragraph {Block} object from the parsed AsciiDoc tree to an
  # HTML backend format (e.g., "html5").
  #
  # As an optimization, scan results and templates are cached for the lifetime
  # of the Ruby process. If the {https://rubygems.org/gems/thread_safe
  # thread_safe} gem is installed, these caches are guaranteed to be thread
  # safe. If this gem is not present, a warning is issued.
  class Converter::TemplateConverter < Converter::Base
    DEFAULT_ENGINE_OPTIONS = {
      :erb =>  { :trim => '<' },
      # TODO line 466 of haml/compiler.rb sorts the attributes; file an issue to make this configurable
      # NOTE AsciiDoc syntax expects HTML/XML output to use double quotes around attribute values
      :haml => { :format => :xhtml, :attr_wrapper => '"', :ugly => true, :escape_attrs => false },
      :slim => { :disable_escape => true, :sort_attrs => false, :pretty => false }
    }

    # QUESTION are we handling how we load the thread_safe support correctly?
    begin
      require 'thread_safe' unless defined? ::ThreadSafe
      @caches = { :scans => ::ThreadSafe::Cache.new, :templates => ::ThreadSafe::Cache.new }
    rescue ::LoadError
      @caches = {}
      # FIXME perhaps only warn if the cache option is enabled?
      warn 'asciidoctor: WARNING: gem \'thread_safe\' is not installed. This gem recommended when using custom backend templates.'
    end

    def self.caches
      @caches
    end

    def self.clear_caches
      @caches[:scans].clear if @caches[:scans]
      @caches[:templates].clear if @caches[:templates]
    end

    def initialize backend, template_dirs, opts = {}
      @backend = backend
      @templates = {}
      @template_dirs = template_dirs
      @eruby = opts[:eruby]
      @engine = opts[:template_engine]
      @engine_options = DEFAULT_ENGINE_OPTIONS.inject({}) do |accum, (engine, default_opts)|
        accum[engine] = default_opts.dup
        accum
      end
      if (overrides = opts[:template_engine_options])
        overrides.each do |engine, override_opts|
          (@engine_options[engine] ||= {}).update override_opts
        end
      end
      @engine_options[:haml][:format] = @engine_options[:slim][:format] = :html5 if opts[:htmlsyntax] == 'html'
      case opts[:template_cache]
      when true
        @caches = self.class.caches
      when ::Hash
        @caches = opts[:template_cache]
      else
        @caches = {}
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
        template_dir = path_resolver.system_path template_dir, nil
        # NOTE last matching template wins for template name if no engine is given
        file_pattern = '*'
        if engine
          file_pattern = %(*.#{engine})
          # example: templates/haml
          if ::File.directory?(engine_dir = (::File.join template_dir, engine))
            template_dir = engine_dir
          end
        end

        # example: templates/html5 or templates/haml/html5
        if ::File.directory?(backend_dir = (::File.join template_dir, backend))
          template_dir = backend_dir
        end

        pattern = ::File.join template_dir, file_pattern

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
          (template.render node).chomp
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
    #
    # Returns the [String] result from rendering the template
    def convert node, template_name = nil
      template_name ||= node.node_name
      unless (template = @templates[template_name])
        raise %(Could not find a custom template to handle transform: #{template_name})
      end
      if template_name == 'document'
        (template.render node).strip
      else
        (template.render node).chomp
      end
    end

    # Public: Convert an {AbstractNode} using the named template with the
    # additional options provided.
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
    def convert_with_options node, template_name = nil, opts = {}
      template_name ||= node.node_name
      unless (template = @templates[template_name])
        raise %(Could not find a custom template to handle transform: #{template_name})
      end
      (template.render node, opts).chomp
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
      @templates.dup.freeze
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
      result = {}
      eruby_loaded = nil
      # Grab the files in the top level of the directory (do not recurse)
      ::Dir.glob(pattern).select {|match| ::File.file? match }.each do |file|
        if (basename = ::File.basename file) == 'helpers.rb' || (path_segments = basename.split '.').size < 2
          next
        end
        # TODO we could derive the basebackend from the minor extension of the template file
        #name, *rest, ext_name = *path_segments # this form only works in Ruby >= 1.9
        name = path_segments[0]
        if name == 'block_ruler'
          name = 'thematic_break'
        elsif name.start_with? 'block_'
          name = name[6..-1]
        end
        ext_name = path_segments[-1]
        template_class = ::Tilt
        extra_engine_options = {}
        if ext_name == 'slim'
          # slim doesn't get loaded by Tilt, so we have to load it explicitly
          Helpers.require_library 'slim' unless defined? ::Slim
        elsif ext_name == 'erb'
          template_class, extra_engine_options = (eruby_loaded ||= load_eruby @eruby)
        end
        next unless ::Tilt.registered? ext_name
        unless template_cache && (template = template_cache[file])
          template = template_class.new file, 1, (@engine_options[ext_name.to_sym] || {}).merge(extra_engine_options)
        end
        result[name] = template
      end
      if ::File.file?(helpers = (::File.join template_dir, 'helpers.rb'))
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
