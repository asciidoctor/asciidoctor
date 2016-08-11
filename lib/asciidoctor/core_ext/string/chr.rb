# Educate Ruby 1.8.7 about the String#chr method.
class String
  def chr
    self[0..0]
  end unless method_defined? :chr
end
