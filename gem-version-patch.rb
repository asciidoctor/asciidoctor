# Overrides Gem::Version.new to restore the hyphen in the version number
Gem::Version.prepend (Module.new do
  def initialize _version
    super
    @version = @version.sub '.pre.', '-'
  end
end)
