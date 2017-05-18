def IO.binread name, length = nil, offset = 0
  File.open name, 'rb' do |f|
    f.seek offset unless offset == 0
    length ? (f.read length) : f.read
  end
end unless IO.respond_to? :binread
