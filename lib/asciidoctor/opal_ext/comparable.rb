# workaround for an infinite loop in Opal 0.6.2 when comparing numbers
module Comparable
  def == other
    return true if equal? other
    return false unless cmp = (self <=> other)
    return `cmp == 0`
  rescue StandardError
    false
  end

  def > other
    unless cmp = (self <=> other)
      raise ArgumentError, "comparison of #{self.class} with #{other.class} failed"
    end
    `cmp > 0`
  end

  def >= other 
    unless cmp = (self <=> other)
      raise ArgumentError, "comparison of #{self.class} with #{other.class} failed"
    end
    `cmp >= 0`
  end
  
  def < other
    unless cmp = (self <=> other)
      raise ArgumentError, "comparison of #{self.class} with #{other.class} failed"
    end
    `cmp < 0`
  end

  def <= other
    unless cmp = (self <=> other)
      raise ArgumentError, "comparison of #{self.class} with #{other.class} failed"
    end
    `cmp <= 0`
  end
end
