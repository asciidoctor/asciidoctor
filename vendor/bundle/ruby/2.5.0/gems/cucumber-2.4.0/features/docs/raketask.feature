@spawn
Feature: Raketask

  In order to use cucumber's rake task
  As a Cuker
  I do not want to see rake's backtraces when it fails
  Also I want to get zero exit status code on failures
  And non-zero exit status code when it pases

  Background:
    Given the standard step definitions
    Given a file named "features/passing_and_failing.feature" with:
      """
      Feature: Sample

        Scenario: Passing
          Given this step passes

        Scenario: Failing
          Given this step raises an error
      """
    Given a file named "Rakefile" with:
      """
        require 'cucumber/rake/task'

        SAMPLE_FEATURE_FILE = 'features/passing_and_failing.feature'

        Cucumber::Rake::Task.new(:pass) do |t|
          t.cucumber_opts = "#{SAMPLE_FEATURE_FILE}:3"
        end

        Cucumber::Rake::Task.new(:fail) do |t|
          t.cucumber_opts = "#{SAMPLE_FEATURE_FILE}:6"
        end
      """

  Scenario: Passing feature
    When I run `bundle exec rake pass`
    Then the exit status should be 0

  Scenario: Failing feature
    When I run `bundle exec rake fail`
    Then the exit status should be 1
    But the output should not contain "rake aborted!"
