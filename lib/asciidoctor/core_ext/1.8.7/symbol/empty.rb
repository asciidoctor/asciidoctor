# Educate Ruby 1.8.7 about the Symbol#empty? method.
class Symbol
  def empty?
    to_s.empty?
  end unless method_defined? :empty?
end
