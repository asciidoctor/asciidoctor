# frozen_string_literal: true
# NOTE remove once minimum required Ruby version is at least 2.4
class Regexp
  alias match? ===
end unless Regexp.method_defined? :match?
