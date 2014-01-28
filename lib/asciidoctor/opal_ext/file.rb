class File
  SEPARATOR = '/'
  ALT_SEPARATOR = nil

  def self.expand_path(path)
    path
  end

  def self.join(*paths)
    paths * SEPARATOR
  end

  def self.basename(path)
    path[((path.rindex(File::SEPARATOR) || -1) + 1)..-1]
  end

  def self.dirname(path)
    path[0..((path.rindex(SEPARATOR) || 0) - 1)]
  end

  def self.extname(path)
    return '' if path.nil_or_empty?
    last_dot_idx = path[1..-1].rindex('.')
    last_dot_idx.nil? ? '' : path[(last_dot_idx + 1)..-1]
  end
end
