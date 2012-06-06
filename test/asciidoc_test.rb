require 'test_helper'

class ProjectTest < Test::Unit::TestCase
  # setup for test
  def setup
    @doc = Asciidoc::Document.new(sample_doc_path(:asciidoc_index))
  end

  def test_title
    assert_equal "Documentation", @doc.title
  end

end
