def IO.write name, string, offset = 0, opts = nil
  File.open name, 'w' do |f|
    f.write string
  end
end unless IO.respond_to? :write
