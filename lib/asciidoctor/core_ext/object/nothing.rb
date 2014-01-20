# A core library extension that defines the method nothing? as an alias to
# optimize checks for nil? or empty? on common object types such as NilClass,
# String, Array and Hash.

class NilClass
  alias :nothing? :nil? unless respond_to? :nothing?
end

class String
  alias :nothing? :empty? unless respond_to? :nothing?
end

class Array
  alias :nothing? :empty? unless respond_to? :nothing?
end

class Hash
  alias :nothing? :empty? unless respond_to? :nothing?
end
