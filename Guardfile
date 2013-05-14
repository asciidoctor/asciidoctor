# A sample Guardfile
# More info at https://github.com/guard/guard#readme

notification :libnotify,
  :display_message => true,
  :timeout => 5, # in seconds
  :append => false,
  :transient => true,
  :urgency => :critical

guard :test do
  watch(%r{^lib/(.+)\.rb$})     { |m| "test/#{m[1]}_test.rb" }
  watch(%r{^test.+_test\.rb$})
  watch('test/test_helper.rb')  { "test" }
end
