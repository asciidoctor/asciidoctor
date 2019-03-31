require "bundler/setup"
require "haml"
require "rbench"

times = (ARGV.first || 1000).to_i

if times == 0 # Invalid parameter
  puts <<END
ruby #$0 [times=1000]
  Benchmark Haml against various other templating languages.
END
  exit 1
end

%w[erb erubis rails active_support action_controller
   action_view action_pack haml/template rbench].each {|dep| require(dep)}

def view
  base = ActionView::Base.new
  base.view_paths << File.join(File.dirname(__FILE__), '/test')
  base
end

def render(view, file)
  view.render :file => file
end

RBench.run(times) do
  column :haml, :title => "Haml"
  column :erb, :title => "ERB"
  column :erubis, :title => "Erubis"

  template_name = 'standard'
  haml_template    = File.read("#{File.dirname(__FILE__)}/test/templates/#{template_name}.haml")
  erb_template     = File.read("#{File.dirname(__FILE__)}/test/erb/#{template_name}.erb")

  report "Cached" do
    obj = Object.new

    Haml::Engine.new(haml_template).def_method(obj, :haml)
    Erubis::Eruby.new(erb_template).def_method(obj, :erubis)
    obj.instance_eval("def erb; #{ERB.new(erb_template, nil, '-').src}; end")

    haml      { obj.haml }
    erb       { obj.erb }
    erubis    { obj.erubis }
  end

  report "ActionView" do
    # To cache the template
    render view, 'templates/standard'
    render view, 'erb/standard'

    haml { render view, 'templates/standard' }
    erb  { render view, 'erb/standard' }
  end

  report "ActionView with deep partials" do
    # To cache the template
    render view, 'templates/action_view'
    render view, 'erb/action_view'

    haml { render view, 'templates/action_view' }
    erb  { render view, 'erb/action_view' }
  end
end
