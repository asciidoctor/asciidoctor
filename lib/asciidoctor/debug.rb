module Asciidoctor
  def self.debug(*args)
    puts *args unless ENV['SUPPRESS_DEBUG'] == 'true'
  end
end

