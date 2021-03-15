require 'asciidoctor'
require 'asciidoctor/extensions'

class FrontMatterPreprocessor < Asciidoctor::Extensions::Preprocessor
  def process document, reader
    lines = reader.lines # get copy of raw lines
    return reader if lines.empty?
    front_matter = []
    if lines.first.chomp == '---'
      lines.shift
      while !lines.empty? && lines.first.chomp != '---'
        front_matter << lines.shift
      end

      if (first = lines.first) && first.chomp == '---'
        document.attributes['front-matter'] = front_matter.join.chomp
        # advance the reader by the number of lines taken
        (front_matter.length + 2).times { reader.advance }
      end
    end
    reader
  end
end

# self-registering
Asciidoctor::Extensions.register do
  preprocessor FrontMatterPreprocessor
end