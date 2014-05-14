require 'asciidoctor/core_ext/object/nil_or_empty'
# Opal barfs here if we use ::RUBY_VERSION_MIN_1_9
unless RUBY_VERSION >= '1.9'
  require 'asciidoctor/core_ext/string/chr'
  # we append .to_s to keep Opal from processing the next require
  require 'asciidoctor/core_ext/symbol/length'.to_s
end
