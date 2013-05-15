# use `guard start -n f` to disable notifications
# or set the environment variable GUARD_NOTIFY=false
notification :libnotify,
  :display_message => true,
  :timeout => 5, # in seconds
  :append => false,
  :transient => true,
  :urgency => :critical

guard :test do
  watch(%r{^lib/(.+)\.rb$}) do |m|
    "test/#{m[1]}_test.rb"
  end
  watch(%r{^test.+_test\.rb$})
  watch('test/test_helper.rb') do
    "test"
  end
end
