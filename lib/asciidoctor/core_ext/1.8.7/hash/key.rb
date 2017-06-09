# Educate Ruby 1.8.7 about the Hash#key method.
class Hash
  alias key index
end
