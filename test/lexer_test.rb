require 'test_helper'

class LexerTest < Test::Unit::TestCase
  # setup for test
  def setup
  end

  def test_is_section_heading
    assert Asciidoctor::Lexer.is_section_heading?("AsciiDoc Home Page", "==================")
    assert Asciidoctor::Lexer.is_section_heading?("=== AsciiDoc Home Page")
  end
end
