# frozen_string_literal: true

begin
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new :lint do |t|
    #t.patterns = %w(lib/**/*.rb Rakefile Gemfile tasks/*.rake)
    t.patterns = %w(lib/**/*.rb test/*.rb features/*.rb Rakefile Gemfile tasks/*.rake)
  end
rescue LoadError => e
  task :lint do
    raise 'Failed to load lint task.
Install required gems using: bundle --path=.bundle/gems
Then, invoke Rake using: bundle exec rake', cause: e
  end
end
