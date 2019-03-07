# frozen_string_literal: true
desc 'Activates coverage'
task :coverage do
  ENV['COVERAGE'] = 'true'
end
