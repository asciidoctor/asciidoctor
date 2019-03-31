Given /^there is a wire server (running |)on port (\d+) which understands the following protocol:$/ do |running, port, table|
  protocol = table.hashes.map do |table_hash|
    table_hash['response'] = table_hash['response'].gsub(/\n/, '\n')
    table_hash
  end

  @server = FakeWireServer.new(port.to_i, protocol)
  start_wire_server if running.strip == "running"
end

Given /^the wire server takes (.*) seconds to respond to the invoke message$/ do |timeout|
  @server.delay_response(:invoke, timeout.to_f)
  start_wire_server
end

Given /^I have environment variable (\w+) set to "([^"]*)"$/ do |variable, value|
  set_env(variable, value)
end

Then(/^the wire server should have received the following messages:$/) do |expected_messages|
  expect(messages_received).to eq expected_messages.raw.flatten
end

module WireHelper
  attr_reader :messages_received

  def start_wire_server
    @messages_received = []
    reader, writer = IO.pipe
    @wire_pid = fork {
      reader.close
      @server.run(writer)
    }
    writer.close
    Thread.new do
      while message = reader.gets
        @messages_received << message.strip
      end
    end
    at_exit { stop_wire_server }
  end

  def stop_wire_server
    return unless @wire_pid
    Process.kill('KILL', @wire_pid)
    Process.wait(@wire_pid)
  rescue Errno::ESRCH
    # No such process - wire server has already been stopped by the After hook
  end
end

Before do
  extend(WireHelper)
end

After do
  stop_wire_server
end
