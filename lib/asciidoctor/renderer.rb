module Asciidoctor
# Public: Methods for rendering Asciidoc Documents, Sections, and Blocks
# using eRuby templates.
class Renderer
  RE_ASCIIDOCTOR_NAMESPACE = /^Asciidoctor::/
  RE_TEMPLATE_CLASS_SUFFIX = /Template$/
  RE_CAMELCASE_BOUNDARY_1 = /([[:upper:]]+)([[:upper:]][[:alpha:]])/
  RE_CAMELCASE_BOUNDARY_2 = /([[:lower:]])([[:upper:]])/

  attr_reader :compact
  attr_reader :cache

  @@global_cache = nil

  # Public: Initialize an Asciidoctor::Renderer object.
  #
  def initialize(options={})
    @debug = !!options[:debug]

    @views = {}
    @compact = options[:compact]
    @cache = nil

    backend = options[:backend]
    case backend
    when 'html5', 'docbook45', 'docbook5'
      eruby = load_eruby options[:eruby]
      #Helpers.require_library 'asciidoctor/backends/' + backend
      require 'asciidoctor/backends/' + backend
      # Load up all the template classes that we know how to render for this backend
      BaseTemplate.template_classes.each do |tc|
        if tc.to_s.downcase.include?('::' + backend + '::') # optimization
          view_name, view_backend = self.class.extract_view_mapping(tc)
          if view_backend == backend
            @views[view_name] = tc.new(view_name, backend, eruby)
          end
        end
      end
    else
      Debug.debug { "No built-in templates for backend: #{backend}" }
    end

    # If user passed in a template dir, let them override our base templates
    if (template_dirs = options.delete(:template_dirs))
      Helpers.require_library 'tilt', true

      if (template_cache = options[:template_cache]) === true
        # FIXME probably want to use our own cache object for more control
        @cache = (@@global_cache ||= TemplateCache.new)
      elsif template_cache
        @cache = template_cache
      end

      view_opts = {
        :erb =>  { :trim => '<>' },
        :haml => { :format => :xhtml, :attr_wrapper => '"', :ugly => true, :escape_attrs => false },
        :slim => { :disable_escape => true, :sort_attrs => false, :pretty => false }
      }

      # workaround until we have a proper way to configure
      if {'html5' => true, 'dzslides' => true, 'deckjs' => true, 'revealjs' => true}.has_key? backend
        view_opts[:haml][:format] = view_opts[:slim][:format] = :html5
      end

      slim_loaded = false
      path_resolver = PathResolver.new
      engine = options[:template_engine]

      template_dirs.each do |template_dir|
        # TODO need to think about safe mode restrictions here
        template_dir = path_resolver.system_path template_dir, nil
        template_glob = '*'
        if engine
          template_glob = "*.#{engine}"
          # example: templates/haml
          if File.directory? File.join(template_dir, engine)
            template_dir = File.join template_dir, engine
          end
        end

        # example: templates/html5 or templates/haml/html5
        if File.directory? File.join(template_dir, backend)
          template_dir = File.join template_dir, backend
        end

        # skip scanning folder if we've already done it for same backend/engine
        if @cache && @cache.cached?(:scan, template_dir, template_glob)
          @views.update(@cache.fetch :scan, template_dir, template_glob)
          next
        end

        helpers = nil
        scan_result = {}
        # Grab the files in the top level of the directory (we're not traversing)
        Dir.glob(File.join(template_dir, template_glob)).
            select{|f| File.file? f }.each do |template|
          basename = File.basename(template)
          if basename == 'helpers.rb'
            helpers = template
            next
          end
          name_parts = basename.split('.')
          next if name_parts.size < 2
          view_name = name_parts.first 
          ext_name = name_parts.last
          if ext_name == 'slim' && !slim_loaded
            # slim doesn't get loaded by Tilt
            Helpers.require_library 'slim', true
          end
          next unless Tilt.registered? ext_name
          opts = view_opts[ext_name.to_sym]
          if @cache
            @views[view_name] = scan_result[view_name] = @cache.fetch(:view, template) {
              Tilt.new(template, nil, opts)
            }
          else
            @views[view_name] = Tilt.new template, nil, opts
          end
        end

        require helpers unless helpers.nil?
        @cache.store(scan_result, :scan, template_dir, template_glob) if @cache
      end
    end
  end

  # Public: Render an Asciidoc object with a specified view template.
  #
  # view   - the String view template name.
  # object - the Object to be used as an evaluation scope.
  # locals - the optional Hash of locals to be passed to Tilt (default {}) (also ignored, really)
  def render(view, object, locals = {})
    if !@views.has_key? view
      raise "Couldn't find a view in @views for #{view}"
    end
    
    @views[view].render(object, locals)
  end

  def views
    readonly_views = @views.dup
    readonly_views.freeze
    readonly_views
  end

  def register_view(view_name, tilt_template)
    # TODO need to figure out how to cache this
    @views[view_name] = tilt_template
  end

  # Internal: Load the eRuby implementation
  #
  # name - the String name of the eRuby implementation (default: 'erb')
  #
  # returns the eRuby implementation class
  def load_eruby(name)
    if name.nil? || !['erb', 'erubis'].include?(name)
      name = 'erb'
    end

    if name == 'erb'
      Helpers.require_library 'erb'
      ::ERB
    elsif name == 'erubis'
      Helpers.require_library 'erubis', true
      ::Erubis::FastEruby
    end
  end

  # TODO better name for this method (and/or field)
  def self.global_cache
    @@global_cache
  end

  # TODO better name for this method (and/or field)
  def self.reset_global_cache
    @@global_cache.clear if @@global_cache
  end

  # Internal: Extracts the view name and backend from a qualified Ruby class
  #
  # The purpose of this method is to determine the view name and backend to
  # which a built-in template class maps. We can make certain assumption since
  # we have control over these class names. The Asciidoctor:: prefix and
  # Template suffix are stripped as the first step in the conversion.
  #
  # qualified_class - The Class or String qualified class name from which to extract the view name and backend
  #
  # Examples
  #
  #   Renderer.extract_view_mapping(Asciidoctor::HTML5::DocumentTemplate)
  #   # => ['document', 'html5']
  #
  #   Renderer.extract_view_mapping(Asciidoctor::DocBook45::BlockSidebarTemplate)
  #   # => ['block_sidebar', 'docbook45']
  #
  # Returns A two-element String Array mapped as [view_name, backend], where backend may be nil
  def self.extract_view_mapping(qualified_class)
    view_name, backend = qualified_class.to_s.
        sub(RE_ASCIIDOCTOR_NAMESPACE, '').
        sub(RE_TEMPLATE_CLASS_SUFFIX, '').
        split('::').reverse
    view_name = camelcase_to_underscore(view_name)
    backend = backend.downcase unless backend.nil?
    [view_name, backend]
  end

  # Internal: Convert a CamelCase word to an underscore-delimited word
  #
  # Examples
  #
  #   Renderer.camelcase_to_underscore('BlockSidebar')
  #   # => 'block_sidebar'
  #
  #   Renderer.camelcase_to_underscore('BlockUlist')
  #   # => 'block_ulist'
  #
  # Returns the String converted from CamelCase to underscore-delimited
  def self.camelcase_to_underscore(str)
    str.gsub(RE_CAMELCASE_BOUNDARY_1, '\1_\2').
        gsub(RE_CAMELCASE_BOUNDARY_2, '\1_\2').downcase
  end

end

class TemplateCache
  attr_reader :cache

  def initialize
    @cache = {}
  end

  # check if a key is available in the cache
  def cached? *key
    @cache.has_key? key
  end

  # retrieves an item from the cache stored in the cache key
  # if a block is given, the block is called and the return
  # value stored in the cache under the specified key
  def fetch(*key)
    if block_given?
      @cache[key] ||= yield
    else
      @cache[key]
    end
  end

  # stores an item in the cache under the specified key
  def store(value, *key)
    @cache[key] = value
  end

  # Clears the cache
  def clear
    @cache = {}
  end
end
end
