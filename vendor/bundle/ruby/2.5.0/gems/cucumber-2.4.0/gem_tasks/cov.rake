desc 'Run all tests and collect code coverage'
task :cov do
  ENV['SIMPLECOV'] = 'features'
  Rake::Task['default'].invoke
end
