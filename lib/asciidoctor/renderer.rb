module Asciidoctor
# Public: Methods for rendering Asciidoc Documents, Sections, and Blocks
# using eRuby templates.
class Renderer
  attr_reader :compact

  # Public: Initialize an Asciidoctor::Renderer object.
  #
  def initialize(options={})
    @debug = !!options[:debug]

    @views = {}
    @compact = options[:compact]

    backend = options[:backend]
    case backend
    when 'html5', 'docbook45'
      eruby = load_eruby options[:eruby]
      #Helpers.require_library 'asciidoctor/backends/' + backend
      require 'asciidoctor/backends/' + backend
      # Load up all the template classes that we know how to render for this backend
      BaseTemplate.template_classes.each do |tc|
        if tc.to_s.downcase.include?('::' + backend + '::') # optimization
          view_name, view_backend = self.class.extract_view_mapping(tc)
          if view_backend == backend
            @views[view_name] = tc.new(view_name, eruby)
          end
        end
      end
    else
      Debug.debug { "No built-in templates for backend: #{backend}" }
    end

    # If user passed in a template dir, let them override our base templates
    if template_dir = options.delete(:template_dir)
      Helpers.require_library 'tilt'

      template_glob = '*'
      if (engine = options[:template_engine])
        template_glob = "*.#{engine}"
        # example: templates/haml
        if File.directory? File.join(template_dir, engine)
          template_dir = File.join template_dir, engine
        end
      end

      # example: templates/html5 or templates/haml/html5
      if File.directory? File.join(template_dir, options[:backend])
        template_dir = File.join template_dir, options[:backend]
      end

      view_opts = {
        :erb =>  { :trim => '<>' },
        :haml => { :attr_wrapper => '"', :ugly => true, :escape_attrs => false },
        :slim => { :disable_escape => true, :sort_attrs => false, :pretty => false }
      }

      # workaround until we have a proper way to configure
      if {'html5' => true, 'dzslides' => true, 'deckjs' => true, 'revealjs' => true}.has_key? backend
        view_opts[:haml][:format] = view_opts[:slim][:format] = :html5
      end

      slim_loaded = false
      helpers = nil
      
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
          Helpers.require_library 'slim'
        end
        next unless Tilt.registered? ext_name
        @views[view_name] = Tilt.new(template, nil, view_opts[ext_name.to_sym])
      end

      require helpers unless helpers.nil?
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

  # Internal: Load the eRuby implementation
  #
  # name - the String name of the eRuby implementation (default: 'erb')
  #
  # returns the eRuby implementation class
  def load_eruby(name)
    if name.nil? || !['erb', 'erubis'].include?(name)
      name = 'erb'
    end

    Helpers.require_library name

    if name == 'erb'
      ::ERB
    elsif name == 'erubis'
      ::Erubis::FastEruby
    end
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
        gsub(/^Asciidoctor::/, '').
        gsub(/Template$/, '').
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
    str.gsub(/([[:upper:]]+)([[:upper:]][[:alpha:]])/, '\1_\2').
        gsub(/([[:lower:]])([[:upper:]])/, '\1_\2').downcase
  end

end
end
