# frozen_string_literal: true
require_relative 'core_ext/nil_or_empty'
require_relative 'core_ext/hash/merge'
unless RUBY_ENGINE == 'opal'
  require_relative 'core_ext/float/truncate'
  require_relative 'core_ext/regexp/is_match'
  require_relative 'core_ext/string/unpack1'
end
