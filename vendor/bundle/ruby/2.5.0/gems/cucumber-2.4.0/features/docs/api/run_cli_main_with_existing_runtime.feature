@spawn
Feature: Run Cli::Main with existing Runtime

  This is the API that Spork uses. It creates an existing runtime.
  When the process forks, Spork them passes the runtime to Cli::Main to
  run it.

    Scenario: Run a single feature
      Given the standard step definitions
      Given a file named "features/success.feature" with:
        """
        Feature:
          Scenario:
            Given this step passes
        """
      When I run the following Ruby code:
        """
        require 'cucumber'
        runtime = Cucumber::Runtime.new
        Cucumber::Cli::Main.new([]).execute!(runtime)
        """
      Then it should pass
      And the output should contain:
        """
        Given this step passes
        """
