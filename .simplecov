SimpleCov.start do
  load_profile 'test_frameworks'
  coverage_dir ENV['COVERAGE_REPORTS'] || 'tmp/coverage'
  if ENV['SHIPPABLE']
    require 'simplecov-csv'
    formatter SimpleCov::Formatter::CSVFormatter
  else
    #formatter SimpleCov::Formatter::MultiFormatter[SimpleCov::Formatter::HTMLFormatter, SimpleCov::Formatter::CSVFormatter]
    formatter SimpleCov::Formatter::HTMLFormatter
  end
end
