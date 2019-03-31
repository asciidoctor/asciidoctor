# Filter that activates steps with obvious pass / fail behaviour
class StandardStepActions < Cucumber::Core::Filter.new
  def test_case(test_case)
    test_steps = test_case.test_steps.map do |step|
      case step.name
      when /fail/
        step.with_action { raise Failure }
      when /pass/
        step.with_action {}
      else
        step
      end
    end

    test_case.with_steps(test_steps).describe_to(receiver)
  end
end

