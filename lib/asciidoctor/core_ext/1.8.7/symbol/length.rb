# Educate Ruby 1.8.7 about the Symbol#empty? and Symbol#length methods.
class Symbol
  def length
    to_s.length
  end unless method_defined? :length
end
