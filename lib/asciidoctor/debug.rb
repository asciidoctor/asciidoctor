module Asciidoctor
  def self.debug(*args)
    puts *args unless ENV['SUPPRESS_DEBUG'] == 'true'
  end

  def self.puts_indented(level, *args)
    thing = " "*level*2
    args.each do |arg|
      puts "#{thing}#{arg}"
    end
  end
end

