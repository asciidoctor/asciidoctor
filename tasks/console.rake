# frozen_string_literal: true

desc 'Open an irb session preloaded with this library'
task :console do
  sh 'bundle console', verbose: false
end
