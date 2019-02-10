# frozen_string_literal: true
# A core library extension that defines the method nil_or_empty? as an alias to
# optimize checks for nil? or empty? on common object types such as NilClass,
# String, Array, Hash, and Numeric.

class NilClass
  alias nil_or_empty? nil? unless method_defined? :nil_or_empty?
end

class String
  alias nil_or_empty? empty? unless method_defined? :nil_or_empty?
end

class Array
  alias nil_or_empty? empty? unless method_defined? :nil_or_empty?
end

class Hash
  alias nil_or_empty? empty? unless method_defined? :nil_or_empty?
end

class Numeric
  alias nil_or_empty? nil? unless method_defined? :nil_or_empty?
end
