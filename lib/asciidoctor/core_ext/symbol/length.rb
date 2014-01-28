# Educate Ruby 1.8.7 about the Symbol#length method.
class Symbol
  def length
    to_s.length
  end unless respond_to? :length
end
