class Dir
  def self.pwd
    ENV['PWD'] || '.'
  end

  def self.getwd
    ENV['PWD'] || '.'
  end

  def self.home
    ENV['HOME']
  end
end
