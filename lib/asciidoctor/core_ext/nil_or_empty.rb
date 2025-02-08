# frozen_string_literal: true

# A core library extension that defines the method nil_or_empty? as an alias to
# optimize checks for nil? or empty? on common object types such as NilClass,
# String, Array, Hash, and Numeric.

module NilOrEmptyRefinement
  refine NilClass do
    alias nil_or_empty? nil? unless method_defined? :nil_or_empty?
  end

  refine String do
    alias nil_or_empty? empty? unless method_defined? :nil_or_empty?
  end

  refine Array do
    alias nil_or_empty? empty? unless method_defined? :nil_or_empty?
  end

  refine Hash do
    alias nil_or_empty? empty? unless method_defined? :nil_or_empty?
  end

  refine  Numeric do
    alias nil_or_empty? nil? unless method_defined? :nil_or_empty?
  end
end
