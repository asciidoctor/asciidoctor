# frozen_string_literal: true
module Asciidoctor
# A module that can be used to mix the {#write} method into a {Converter} implementation to allow the converter to
# control how the output is written to disk.
module Writer
  # Public: Writes the output to the specified target file name or stream.
  #
  # output - The output String to write
  # target - The String file name or stream object to which the output should be written.
  #
  # Returns nothing
  def write output, target
    if target.respond_to? :write
      # ensure there's a trailing newline to be nice to terminals
      target.write output.chomp + LF
    else
      # QUESTION shouldn't we ensure a trailing newline here too?
      ::File.write target, output, mode: FILE_WRITE_MODE
    end
    nil
  end
end

module VoidWriter
  include Writer

  # Public: Does not write output
  def write output, target; end
end
end
