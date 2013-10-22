module Asciidoctor
module Helpers
  # Internal: Require the specified library using Kernel#require.
  #
  # Attempts to load the library specified in the first argument using the
  # Kernel#require. Rescues the LoadError if the library is not available and
  # passes a message to Kernel#fail to communicate to the user that processing
  # is being aborted. If a gem_name is specified, the failure message
  # communicates that a required gem is not installed.
  #
  # name  - the String name of the library to require.
  # gem   - a Boolean that indicates whether this library is provided by a RubyGem,
  #         or the String name of the RubyGem if it differs from the library name
  #         (default: true)
  #
  # returns the return value of Kernel#require if the library is available,
  # otherwise Kernel#fail is called with an appropriate message.
  def self.require_library(name, gem = true)
    begin
      require name
    rescue LoadError => e
      if gem
        fail "asciidoctor: FAILED: required gem '#{gem === true ? name : gem}' is not installed. Processing aborted."
      else
        fail "asciidoctor: FAILED: #{e.message.chomp '.'}. Processing aborted."
      end
    end
  end

  # Public: Encode a string for inclusion in a URI
  #
  # str - the string to encode
  #
  # returns an encoded version of the str
  def self.encode_uri(str)
    str.gsub(REGEXP[:uri_encode_chars]) do
      match = $&
      buf = ''
      match.each_byte do |c|
        buf << sprintf('%%%02X', c)
      end
      buf
    end
  end

  # Public: Removes the file extension from filename and returns the result
  #
  # file_name - The String file name to process
  #
  # Examples
  #
  #   Helpers.rootname('part1/chapter1.adoc')
  #   # => "part1/chapter1"
  #
  # Returns the String filename with the file extension removed
  def self.rootname(file_name)
    ext = File.extname(file_name)
    if ext.empty?
      file_name
    else
      file_name[0...-ext.length]
    end
  end

  def self.mkdir_p(dir)
    unless File.directory? dir
      parent_dir = File.dirname(dir)
      if !File.directory?(parent_dir = File.dirname(dir)) && parent_dir != '.'
        mkdir_p(parent_dir)
      end
      Dir.mkdir(dir)
    end
  end

  # Public: Create a copy of options such that no references are shared
  # returns A deep clone of the options Hash
  def self.clone_options(opts)
    clone = opts.dup
    if opts.has_key? :attributes
      clone[:attributes] = opts[:attributes].dup
    end
    clone
  end
end
end
