# Public: Methods for rendering Asciidoc Documents, Sections, and Blocks
# using eRuby templates.
class Asciidoctor::Renderer
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
      #Asciidoctor.require_library 'asciidoctor/backends/' + backend
      require 'asciidoctor/backends/' + backend
      # Load up all the template classes that we know how to render for this backend
      Asciidoctor::BaseTemplate.template_classes.each do |tc|
        if tc.to_s.downcase.include?('::' + backend + '::') # optimization
          view_name, view_backend = self.class.extract_view_mapping(tc)
          if view_backend == backend
            @views[view_name] = tc.new(view_name, eruby)
          end
        end
      end
    else
      Asciidoctor.debug { "No built-in templates for backend: #{backend}" }
    end

    # If user passed in a template dir, let them override our base templates
    if template_dir = options.delete(:template_dir)
      Asciidoctor.require_library 'tilt'

      Asciidoctor.debug {
        msg = []
        msg << "Views going in are like so:"
        msg << @views.map {|k, v| "#{k}: #{v}"}
        msg << '=' * 60
        msg * "\n"
      }
      
      # Grab the files in the top level of the directory (we're not traversing)
      files = Dir.glob(File.join(template_dir, '*')).select{|f| File.stat(f).file?}
      files.inject(@views) do |view_hash, view|
        name = File.basename(view).split('.').first
        view_hash.merge!(name => Tilt.new(view, nil, :trim => '<>', :attr_wrapper => '"'))
      end

      Asciidoctor.debug {
        msg = []
        msg << "Views going in are like so:"
        msg << @views.map {|k, v| "#{k}: #{v}"}
        msg << '=' * 60
        msg * "\n"
      }
    end

    @render_stack = []
  end

  # Public: Render an Asciidoc object with a specified view template.
  #
  # view   - the String view template name.
  # object - the Object to be used as an evaluation scope.
  # locals - the optional Hash of locals to be passed to Tilt (default {}) (also ignored, really)
  def render(view, object, locals = {})
    @render_stack.push([view, object])

    if !@views.has_key? view
      raise "Couldn't find a view in @views for #{view}"
    else
      Asciidoctor.debug { "View for #{view} is #{@views[view]}, object is #{object}" }
    end
    
    ret = @views[view].render(object, locals)

    if @debug
      prefix = ''
      STDERR.puts '=' * 80
      STDERR.puts "Rendering:"
      @render_stack.each do |stack_view, stack_obj|
        obj_info = case stack_obj
                   when Asciidoctor::Section; "SECTION #{stack_obj.title}"
                   when Asciidoctor::Block;
                     if stack_obj.context == :dlist
                       dt_list = stack_obj.buffer.map{|dt,dd| dt.content.strip}.join(', ')
                       "BLOCK :dlist (#{dt_list})"
                     #else
                     #  "BLOCK #{stack_obj.context.inspect}"
                     end
                   else stack_obj.class
                   end
        STDERR.puts "#{prefix}#{stack_view}: #{obj_info}"
        prefix << '  '
      end
      STDERR.puts '-' * 80
      #STDERR.puts ret.inspect
      STDERR.puts '=' * 80
      STDERR.puts
    end

    @render_stack.pop
    ret
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

    Asciidoctor.require_library name

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
