require 'stringio'
io = StringIO.new String.new %(é\n\n#{Encoding.default_external}:#{Encoding.default_internal}), encoding: Encoding::UTF_8
io.set_encoding Encoding.default_external, Encoding.default_internal
$stdin = io
