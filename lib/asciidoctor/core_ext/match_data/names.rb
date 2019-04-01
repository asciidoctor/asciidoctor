# frozen_string_literal: true
# NOTE remove once implemented in Opal; see https://github.com/opal/opal/issues/1964
class MatchData
  def names
    []
  end
end unless MatchData.method_defined? :names
