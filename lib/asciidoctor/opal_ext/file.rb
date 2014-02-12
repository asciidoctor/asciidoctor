class Kernel
  # basic implementation of open, enough to work
  # with reading files over XmlHttpRequest
  def open(path, *rest)
    file = File.new(path, *rest)
    if block_given?
      yield file
    else
      file
    end
  end
end

class File
  SEPARATOR = '/'
  ALT_SEPARATOR = nil

  attr_reader :eof
  attr_reader :lineno
  attr_reader :path

  def initialize(path, mode = 'r')
    @path = path
    @contents = nil
    @eof = false
    @lineno = 0
  end

  def read
    if @eof
      ''
    else
      res = File.read(@path)
      @eof = true
      @lineno = res.size
      res
    end
  end

  def each_line(separator = $/, &block)
    if @eof
      return block_given? ? self : [].to_enum
    end

    if block_given?
      lines = File.read(@path)
      %x{
        self.eof = false;
        self.lineno = 0; 
        var chomped  = #{lines.chomp},
            trailing = lines.length != chomped.length,
            splitted = chomped.split(separator);

        for (var i = 0, length = splitted.length; i < length; i++) {
          self.lineno += 1;
          if (i < length - 1 || trailing) {
            #{yield `splitted[i] + separator`};
          }
          else {
            #{yield `splitted[i]`};
          }
        }
        self.eof = true;
      }
      self
    else
      read.each_line
    end
  end

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

  def self.file?(path)
    true
  end
  
  def self.read(path)
    %x{
      var data = ''
      try {
        var xhr = new XMLHttpRequest();
        xhr.open('GET', path, false);
        xhr.addEventListener('load', function() {
          data = xhr.responseText;
        });
        xhr.overrideMimeType('text/plain');
        xhr.send(null);
      }
      catch (xhrError) {}
    }
    `data`
  end
end
