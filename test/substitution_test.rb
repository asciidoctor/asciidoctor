require 'test_helper'

context "Substitions" do
  setup do
    @rendered = render_string(":frog:    Yo, I am a frog.\n\nA frog says, '{frog}'")
  end

  test "defines" do
    result = Nokogiri::HTML(@rendered)
    assert_equal("A frog says, 'Yo, I am a frog.'", result.css("p").first.content.strip)
  end
end