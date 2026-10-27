# frozen_string_literal: true
# NOTE remove once minimum required Ruby version is at least 2.4
String.prepend (Module.new do
  def unpack1 format
    (unpack format)[0]
  end
end) unless String.method_defined? :unpack1
