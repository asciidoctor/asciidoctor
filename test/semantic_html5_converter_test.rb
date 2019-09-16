# frozen_string_literal: true
require_relative 'test_helper'

context 'Semantic HTML 5 converter' do
  (Dir.glob "#{ASCIIDOCTOR_TEST_DIR}/fixtures/sem-html5-scenarios/*.adoc").each do |input_filename|
    input_stem = input_filename.slice 0, input_filename.length - 5
    scenario_name = input_stem.gsub '/', '::'
    input_filename = File.absolute_path input_filename
    output_filename = File.absolute_path %(#{input_stem}.html)
    test scenario_name do
      input = IO.read input_filename, mode: 'r:UTF-8', newline: :universal
      expected = (IO.read output_filename, mode: 'r:UTF-8', newline: :universal).chomp
      result = (convert_string_to_embedded input, backend: 'sem-html5')
      assert_equal expected, result
    end
  end
end