# Borrowed and heavily adjusted from:
# https://github.com/metricfu/metric_fu/blob/master/spec/capture_warnings.rb
require "fileutils"

class FailOnWarnings
  def initialize
    @stderr_stream = StringIO.new
    @app_root = Dir.pwd
  end

  def collect_warnings
    $stderr = @stderr_stream
    $VERBOSE = true
  end

  def process_warnings
    lines = close_stream
    app_warnings, other_warnings = split_lines(lines)

    print_own_warnings(app_warnings) if app_warnings.any?
    write_other_warnings_to_tmp(other_warnings) if other_warnings.any?
    fail_script(app_warnings) if app_warnings.any?
  end

private

  def close_stream
    $stderr = STDERR

    @stderr_stream.rewind
    lines = @stderr_stream.read.split("\n")
    lines.uniq!
    @stderr_stream.close
    lines
  end

  def split_lines(lines)
    lines.partition { |line| line.include?(@app_root) }
  end

  def print_own_warnings(app_warnings)
    puts ""
    puts ""
    puts <<-WARNINGS
#{'-' * 30} app warnings: #{'-' * 30}
    #{app_warnings.join("\n")}
    #{'-' * 75}
    WARNINGS
  end

  def write_other_warnings_to_tmp(other_warnings)
    output_dir = File.join(@app_root, "tmp")
    FileUtils.mkdir_p(output_dir)
    output_file = File.join(output_dir, "warnings.txt")
    File.open(output_file, "w") do |file|
      file.write(other_warnings.join("\n") << "\n")
    end
    puts
    puts "Non-app warnings written to tmp/warnings.txt"
    puts
  end

  def fail_script(app_warnings)
    abort "Failing build due to app warnings: #{app_warnings.inspect}"
  end
end

warning_collector = FailOnWarnings.new
warning_collector.collect_warnings

RSpec.configure do |config|
  config.after(:suite) do
    warning_collector.process_warnings
  end
end
