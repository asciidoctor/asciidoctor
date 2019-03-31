Feature: One line step definitions

  Everybody knows you can do step definitions in Cucumber
  but did you know you can do this?

  Scenario: Call a method in World directly from a step def
    Given a file named "features/step_definitions/steps.rb" with:
      """
      module Driver
        def do_action
          @done = true
        end

        def assert_done
          expect(@done).to be true
        end
      end
      World(Driver)

      When /I do the action/, :do_action
      Then /The action should be done/, :assert_done
      """
    And a file named "features/action.feature" with:
      """
      Feature:
        Scenario:
          When I do the action
          Then the action should be done
      """
    When I run `cucumber`
    Then it should pass

  Scenario: Call a method on an actor in the World directly from a step def
    Given a file named "features/step_definitions/steps.rb" with:
      """
      class Thing
        def do_action
          @done = true
        end

        def assert_done
          expect(@done).to be true
        end
      end

      module Driver
        def thing
          @thing ||= Thing.new
        end
      end
      World(Driver)

      When /I do the action to the thing/, :do_action, :on => lambda { thing }
      Then /The thing should be done/, :assert_done, :on => lambda { thing }
      """
    And a file named "features/action.feature" with:
      """
      Feature:
        Scenario:
          When I do the action to the thing
          Then the thing should be done
      """
    When I run `cucumber`
    Then it should pass

