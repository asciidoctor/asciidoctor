require 'stringio'
require 'kramdown'

describe "README.md code snippet" do
  let(:code_blocks) do
    markdown = File.read(File.expand_path(File.dirname(__FILE__) + '/../README.md'))
    parse_ruby_from(markdown)
  end

  it "executes with the expected output" do
    code, output = *code_blocks
    expect(execute_ruby(code)).to eq output
  end

  def execute_ruby(code)
    capture_stdout do
      eval code, binding
    end
  end

  def parse_ruby_from(markdown)
    code_blocks = Kramdown::Parser::GFM.parse(markdown).first.children.select { |e| e.type == :codeblock }.map(&:value)
    expect(code_blocks).not_to be_empty
    code_blocks
  end

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    result = $stdout.string
    $stdout = original
    result
  end

end
