# Educate Ruby 1.8.7 about the String#chr method.
class String
  def chr
    slice 0, 1
  end unless method_defined? :chr
end
