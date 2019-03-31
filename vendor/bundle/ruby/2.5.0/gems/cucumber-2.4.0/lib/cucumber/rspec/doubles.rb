require 'rspec/mocks'

World(RSpec::Mocks::ExampleMethods)

Before do
  if RSpec::Mocks::Version::STRING >= "2.9.9"
    RSpec::Mocks.setup
  else
    RSpec::Mocks.setup(self)
  end
end

After do
  begin
    RSpec::Mocks.verify
  ensure
    RSpec::Mocks.teardown
  end
end
