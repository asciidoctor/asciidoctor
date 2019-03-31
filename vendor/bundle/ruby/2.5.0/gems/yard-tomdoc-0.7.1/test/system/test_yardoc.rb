dir = File.expand_path(File.dirname(__FILE__))
tmp = File.expand_path(dir + '/../../tmp')

require "helper"

# This test is design to run `yard doc` on the sample project and
# check to make sure it was produced successufully.
#
# NOTE: There is only one test b/c generation has to happen first
# and minitest will randomize the order of tests. You have fix?
#
describe "yard doc" do

  before do
    FileUtils.mkdir(tmp) unless File.directory?(tmp)
    FileUtils.cp_r(dir + '/sample', tmp)
  end

  it "should generate documentation" do
    Dir.chdir(tmp + '/sample') do
      success = system "yard doc --plugin yard-tomdoc lib/"

      assert(success, "failed to generate yard documentation")
      assert File.directory?('doc')

      # TODO: more verifications
    end
  end

end

