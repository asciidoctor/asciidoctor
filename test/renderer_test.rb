require 'test_helper'

context 'Renderer' do

  test 'should extract view mapping from built-in template with one segment and backend' do
    view_name, view_backend = Asciidoctor::Renderer.extract_view_mapping('Asciidoctor::HTML5::DocumentTemplate') 
    assert_equal 'document', view_name
    assert_equal 'html5', view_backend
  end

  test 'should extract view mapping from built-in template with two segments and backend' do
    view_name, view_backend = Asciidoctor::Renderer.extract_view_mapping('Asciidoctor::DocBook45::BlockSidebarTemplate') 
    assert_equal 'block_sidebar', view_name
    assert_equal 'docbook45', view_backend
  end

  test 'should extract view mapping from built-in template without backend' do
    view_name, view_backend = Asciidoctor::Renderer.extract_view_mapping('Asciidoctor::DocumentTemplate') 
    assert_equal 'document', view_name
    assert view_backend.nil?
  end
end
