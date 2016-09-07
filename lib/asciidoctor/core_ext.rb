require 'asciidoctor/core_ext/object/nil_or_empty'
require 'asciidoctor/core_ext/string/limit'
unless RUBY_ENGINE == 'opal'
  unless RUBY_MIN_VERSION_1_9
    require 'asciidoctor/core_ext/string/chr'
    require 'asciidoctor/core_ext/symbol/length'
  end
end
