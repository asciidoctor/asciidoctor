Feature: Post Configuration Hook [#423]

  In order to extend Cucumber
  As a developer
  I want to manipulate the Cucumber configuration after it has been created

  # Fails on Travis under JRuby
  @spawn
  @wip-jruby
  Scenario: Using options directly gets a deprecation warning
    Given a file named "features/support/env.rb" with:
      """
      AfterConfiguration do |config|
        config.options[:blah]
      end
      """
    When I run `cucumber features`
    Then the stderr should contain:
      """
      Deprecated
      """

  Scenario: Changing the output format
    Given a file named "features/support/env.rb" with:
      """
      AfterConfiguration do |config|
        config.formats << ['html', config.out_stream]
      end
      """
    When I run `cucumber features`
    Then the stderr should not contain anything
    And the output should contain:
      """
      html
      """

  Scenario: feature directories read from configuration
    Given a file named "features/support/env.rb" with:
      """
      AfterConfiguration do |config|
        config.out_stream << "AfterConfiguration hook read feature directories: #{config.feature_dirs.join(', ')}"
      end
      """
    When I run `cucumber features`
    Then the stderr should not contain anything
    And the output should contain:
      """
      AfterConfiguration hook read feature directories: features
      """
