class Entry
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  attr_accessor :name

  def initialize(attributes = {})
    attributes.each do |name, value|
      send("#{name}=", value)
    end
  end

  def persisted?
    false
  end
end
