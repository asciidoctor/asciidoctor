require_relative 'test_helper'

context 'Docbook' do
  context 'TableStripes' do
    def get_table(attributes) 
        asciidoc_content = <<~ASCIIDOC
          [#{attributes.map { |k, v| "#{k}=#{v}" }.join(',')}]
          |====
          | Column 1 | Column 2
          | Cell 1 | Cell 2
          | Cell 3 | Cell 4
          |====
        ASCIIDOC
        return asciidoc_content
    end

    test 'even' do
      attributes = { 'stripes' => 'even' }
      asciidoc_content = get_table attributes

      subject = Asciidoctor.convert(asciidoc_content, backend: 'docbook5')
      assert_xpath '/informaltable[@tabstyle="stripes-even"]', subject, 1
    end

    test 'odd' do
      attributes = { 'stripes' => 'odd' }
      asciidoc_content = get_table attributes

      subject = Asciidoctor.convert(asciidoc_content, backend: 'docbook5')
      assert_xpath '/informaltable[@tabstyle="stripes-odd"]', subject, 1
    end

    test 'all' do
      attributes = { 'stripes' => 'all' }
      asciidoc_content = get_table attributes

      subject = Asciidoctor.convert(asciidoc_content, backend: 'docbook5')
      assert_xpath '/informaltable[@tabstyle="stripes-all"]', subject, 1
    end
  end
end

