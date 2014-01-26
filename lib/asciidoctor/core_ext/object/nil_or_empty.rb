# A core library extension that defines the method nil_or_empty? as an alias to
# optimize checks for nil? or empty? on common object types such as NilClass,
# String, Array and Hash.

class NilClass
  alias :nil_or_empty? :nil? unless respond_to? :nil_or_empty?
end

class String
  alias :nil_or_empty? :empty? unless respond_to? :nil_or_empty?
end

class Array
  alias :nil_or_empty? :empty? unless respond_to? :nil_or_empty?
end

class Hash
  alias :nil_or_empty? :empty? unless respond_to? :nil_or_empty?
end

class Numeric
  alias :nil_or_empty? :nil? unless respond_to? :nil_or_empty?
end
