class Dir
  def self.pwd
    '.'
  end

  def self.home
    ENV['HOME']
  end
end
