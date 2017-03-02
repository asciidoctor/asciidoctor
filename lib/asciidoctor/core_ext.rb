require 'asciidoctor/core_ext/nil_or_empty'
require 'asciidoctor/core_ext/regexp/is_match'
if RUBY_MIN_VERSION_1_9
  require 'asciidoctor/core_ext/string/limit_bytesize'
elsif RUBY_ENGINE != 'opal'
  require 'asciidoctor/core_ext/1.8.7/string/chr'
  require 'asciidoctor/core_ext/1.8.7/string/limit_bytesize'
  require 'asciidoctor/core_ext/1.8.7/symbol/empty'
  require 'asciidoctor/core_ext/1.8.7/symbol/length'
end
