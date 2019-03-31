# NOTE: Very simple tests for what system we are on, extracted for sharing
#   between Rakefile, gemspec, and spec_helper. Not for use in actual library.

def on_travis?
  ENV['CI'] == 'true'
end

def on_jruby?
  (defined?(RUBY_ENGINE) && 'jruby' == RUBY_ENGINE)
end

def on_1_8?
  RUBY_VERSION.start_with? '1.8'
end