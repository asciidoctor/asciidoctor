# Public: Methods for rendering Asciidoc Documents, Sections, and Blocks
# using erb templates.
class Asciidoctor::Renderer
  # Public: Initialize an Asciidoctor::Renderer object.
  #
  def initialize(options={})
    @debug = !!options[:debug]

    @views = {}

    # Load up all the template classes that we know how to render
    BaseTemplate.template_classes.each do |tc|
      view = tc.to_s.underscore.gsub(/_template$/, '')
      @views[view] = tc.new
    end

    # If user passed in a template dir, let them override our base templates
    if template_dir = options.delete(:template_dir)
      puts "Views going in are like so:"
      @views.each_pair do |k, v|
        puts "#{k}: #{v}"
      end
      puts "="*60
      # Grab the files in the top level of the directory (we're not traversing)
      files = Dir.glob(File.join(template_dir, '*')).select{|f| File.stat(f).file?}
      files.inject(@views) do |view_hash, view|
        name = File.basename(view).split('.').first
        view_hash.merge!(name => Tilt.new(view, nil, :trim => '<>'))
      end
      puts "Views are now like so:"
      @views.each_pair do |k, v|
        puts "#{k}: #{v}"
      end
      puts "="*60
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
    if @views[view].nil?
      raise "Couldn't find a view in @views for #{view}"
    else
      Asciidoctor.debug "View for #{view} is #{@views[view]}, object is #{object}"
    end
    ret = @views[view].render(object, locals)

    if @debug
      prefix = ''
      STDERR.puts '=' * 80
      STDERR.puts "Rendering:"
      @render_stack.each do |stack_view, stack_obj|
        obj_info = case stack_obj
                   when Asciidoctor::Section; "SECTION #{stack_obj.name}"
                   when Asciidoctor::Block;
                     if stack_obj.context == :dlist
                       dt_list = stack_obj.buffer.map{|dt,dd| dt.content.strip}.join(', ')
                       "BLOCK :dlist (#{dt_list})"
                     else
                       "BLOCK #{stack_obj.context.inspect}"
                     end
                   else stack_obj.class
                   end
        STDERR.puts "#{prefix}#{stack_view}: #{obj_info}"
        prefix << '  '
      end
      STDERR.puts '-' * 80
      STDERR.puts ret.inspect
      STDERR.puts '=' * 80
      STDERR.puts
    end

    @render_stack.pop
    ret
  end
end
