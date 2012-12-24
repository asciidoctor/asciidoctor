module Asciidoctor
  @show_debug = nil

  def self.debug(*args)
    puts args if self.show_debug_output?
  end

  def self.set_debug(value)
    @show_debug = value
  end

  def self.show_debug_output?
    @show_debug || (ENV['DEBUG'] == 'true' && ENV['SUPPRESS_DEBUG'] != 'true')
  end

  def self.puts_indented(level, *args)
    thing = " "*level*2
    args.each do |arg|
      self.debug "#{thing}#{arg}"
    end
  end
end

