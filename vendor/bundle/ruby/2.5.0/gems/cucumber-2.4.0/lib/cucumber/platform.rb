# Detect the platform we're running on so we can tweak behaviour
# in various places.
require 'rbconfig'
require 'cucumber/core/platform'

module Cucumber
  unless defined?(Cucumber::VERSION)
    VERSION       = File.read(File.expand_path("../version", __FILE__))
    BINARY        = File.expand_path(File.dirname(__FILE__) + '/../../bin/cucumber')
    LIBDIR        = File.expand_path(File.dirname(__FILE__) + '/../../lib')
    RAILS         = defined?(Rails)
    RUBY_BINARY   = File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name'])
    RUBY_2_2      = RUBY_VERSION =~ /^2\.2/
    RUBY_2_1      = RUBY_VERSION =~ /^2\.1/
    RUBY_2_3      = RUBY_VERSION =~ /^2\.3/

    class << self
      attr_accessor :use_full_backtrace

      # @private
      def file_mode(m, encoding="UTF-8")
        "#{m}:#{encoding}"
      end
    end
    self.use_full_backtrace = false
  end
end
