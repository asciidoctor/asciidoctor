module Asciidoctor
module Helpers
  # Internal: Prior to invoking Kernel#require, issues a warning urging a
  # manual require if running in a threaded environment.
  #
  # name  - the String name of the library to require.
  #
  # returns false if the library is detected on the load path or the return
  # value of delegating to Kernel#require
  def self.require_library(name, gem_name = nil)
    if Thread.list.size > 1
      main_script = "#{name}.rb"
      main_script_path_segment = "/#{name}.rb"
      if !$LOADED_FEATURES.detect {|p| p == main_script || p.end_with?(main_script_path_segment) }.nil?
        return false
      else
        warn "WARN: asciidoctor is autoloading '#{name}' in threaded environment. " +
           "The use of an explicit require '#{name}' statement is recommended."
      end
    end
    begin
      require name
    rescue LoadError => e
      if gem_name
        fail "asciidoctor: FAILED: required gem '#{gem_name === true ? name : gem_name}' is not installed. Processing aborted."
      else
        fail "asciidoctor: FAILED: #{e.chomp '.'}. Processing aborted."
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
