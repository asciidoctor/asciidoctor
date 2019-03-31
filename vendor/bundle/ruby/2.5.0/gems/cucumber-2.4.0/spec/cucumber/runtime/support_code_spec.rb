require 'spec_helper'

module Cucumber
  describe Runtime::SupportCode do
    let(:user_interface) { double('user interface') }
    subject { Runtime::SupportCode.new(user_interface, configuration) }
    let(:configuration) { Configuration.new(options) }
    let(:options) { {}}
    let(:dsl) do
      @rb = subject.ruby
      Object.new.extend(RbSupport::RbDsl)
    end


  end
end
