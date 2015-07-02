class BasicObject
  # Provides implementation for missing != method BasicObject. Allows the
  # method :!= to be sent to an object.
  def != other
    `self !== other`
  end
end

# workaround for an infinite loop in Opal 0.6.x when comparing numbers
module Comparable
  def == other
    return true if equal? other
    # if <=> returns nil, assume these objects can't be compared (and thus not equal)
    return false unless res = (self <=> other)
    return `res == 0`
  rescue StandardError
    false
  end

  def != other
    return false if equal? other
    # if <=> returns nil, assume these objects can't be compared (and thus not equal)
    return true unless res = (self <=> other)
    return `res != 0`
  rescue StandardError
    true
  end

  def > other
    unless res = (self <=> other)
      raise ArgumentError, %(comparison of #{self.class} with #{other.class} failed)
    end
    `res > 0`
  end

  def >= other 
    unless res = (self <=> other)
      raise ArgumentError, %(comparison of #{self.class} with #{other.class} failed)
    end
    `res >= 0`
  end
  
  def < other
    unless res = (self <=> other)
      raise ArgumentError, %(comparison of #{self.class} with #{other.class} failed)
    end
    `res < 0`
  end

  def <= other
    unless res = (self <=> other)
      raise ArgumentError, %(comparison of #{self.class} with #{other.class} failed)
    end
    `res <= 0`
  end
end
