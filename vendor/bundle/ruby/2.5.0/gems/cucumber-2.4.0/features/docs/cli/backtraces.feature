Feature: Backtraces

  In order to discover errors quickly
  As a cuker
  I want to see backtraces for failures

  Background:
    Given a file named "features/failing_hard.feature" with:
      """
      Feature: Sample
        Scenario: Example
          Given failing
      """

  @jruby
  Scenario: Backtraces enabled
    Given a file named "features/step_definitions/steps.rb" with:
      """
      require 'java'
      java_import 'java.util.Collections'

      Given /^failing$/ do
        Collections.empty_list.add 1
      end
      """
    When I run `cucumber features/failing_hard.feature`
    Then it should fail with:
      """
      Feature: Sample

        Scenario: Example # features/failing_hard.feature:2
          Given failing   # features/step_definitions/steps.rb:4
             (Java::JavaLang::UnsupportedOperationException)
            java.util.AbstractList.add(java/util/AbstractList.java:
      """

