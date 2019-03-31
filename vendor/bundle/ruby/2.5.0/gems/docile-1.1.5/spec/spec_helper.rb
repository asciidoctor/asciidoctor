require File.expand_path('on_what', File.dirname(File.dirname(__FILE__)))

begin
  require 'simplecov'
  require 'coveralls'

  # On Ruby 1.9+ use SimpleCov and publish to Coveralls.io
  if !on_1_8?
    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
      SimpleCov::Formatter::HTMLFormatter,
      Coveralls::SimpleCov::Formatter
    ]
    SimpleCov.start do
      add_filter '/spec/'    # exclude test code
      add_filter '/vendor/'  # exclude gems which are vendored on Travis CI
    end

    # Remove Docile, which was required by SimpleCov, to require again later
    Object.send(:remove_const, :Docile)
    $LOADED_FEATURES.reject! { |f| f =~ /\/docile\// }
  end
rescue LoadError
  warn 'warning: simplecov/coveralls gems not found; skipping coverage'
end

lib_dir = File.join(File.dirname(File.dirname(__FILE__)), 'lib')
$LOAD_PATH.unshift lib_dir unless $LOAD_PATH.include? lib_dir

# Require Docile again, now with coverage enabled on 1.9+
require 'docile'
