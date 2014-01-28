require 'asciidoctor/core_ext/object/nil_or_empty'
unless RUBY_MIN_VERSION_1_9
  require 'asciidoctor/core_ext/string/chr'
  require 'asciidoctor/core_ext/symbol/length'
end
