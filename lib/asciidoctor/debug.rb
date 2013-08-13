module Asciidoctor
module Debug
  @show_debug = nil
  
  def self.debug
    warn yield if self.show_debug_output?
  end
  
  def self.set_debug(value)
    @show_debug = value
  end
  
  def self.show_debug_output?
    @show_debug || (ENV['DEBUG'] == 'true' && ENV['SUPPRESS_DEBUG'] != 'true')
  end
  
  def self.puts_indented(level, *args)
    indentation = " " * level * 2
  
    args.each do |arg|
      self.debug { "#{indentation}#{arg}" }
    end
  end
end
end
