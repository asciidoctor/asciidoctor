# Educate Ruby 1.8.7 about the Base64#strict_encode64 method.
module Base64
  def strict_encode64 bin
    (self.encode64 bin).delete %(\n)
  end
end
