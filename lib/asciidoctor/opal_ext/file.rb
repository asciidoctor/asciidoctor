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
      %x(
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
      )
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
    (offset = path.rindex SEPARATOR) ? path[(offset + 1)..-1] : path
  end

  def self.dirname(path)
    (offset = path.rindex SEPARATOR) ? path[0..(offset - 1)] : '.'
  end

  def self.extname(path)
    return '' if path.nil_or_empty?
    last_dot_idx = path[1..-1].rindex('.')
    last_dot_idx.nil? ? '' : path[(last_dot_idx + 1)..-1]
  end

  # TODO use XMLHttpRequest HEAD request unless in local file mode
  def self.file?(path)
    true
  end
  
  def self.read(path)
    case JAVASCRIPT_PLATFORM
    when 'node'
      %x(return require('fs').readFileSync(path, 'utf8');)
    when 'java-nashorn'
      %x(
        var Paths = Java.type('java.nio.file.Paths');
        var Files = Java.type('java.nio.file.Files');
        var lines = Files.readAllLines(Paths.get(path), Java.type('java.nio.charset.StandardCharsets').UTF_8);
        var data = [];
        lines.forEach(function(line) { data.push(line); });
        return data.join("\n");
      )
    #when 'java-rhino'
    when 'browser'
      %x(
        var data = '';
        var status = -1;
        try {
          var xhr = new XMLHttpRequest();
          xhr.open('GET', path, false);
          xhr.addEventListener('load', function() {
            status = this.status;
            // status is 0 for local file mode (i.e., file://)
            if (status == 0 || status == 200) {
              data = this.responseText;
            }
          });
          xhr.overrideMimeType('text/plain');
          xhr.send();
        }
        catch (e) {
          status = 0;
        }
        // assume that no data in local file mode means it doesn't exist
        if (status == 404 || (status == 0 && data == '')) {
          throw #{IOError.new `'No such file or directory: ' + path`};
        }
        return data;
      )
    # afx means asciidocfx
    when 'javafx'
      %x(
        var data = '';

        if(afx) {
          try {
            data = afx.readAsciidoctorResource(path,null);
            if(data==404) {
	      throw new Error();
	    }
          }
          catch (e) {
            throw #{IOError.new `'No such file or directory: ' + path`};
          }
          return data;
        }

        var status = -1;
        try {
          var xhr = new XMLHttpRequest();
          xhr.open('GET', path, false);
          xhr.addEventListener('load', function() {
            status = this.status;
            // status is 0 for local file mode (i.e., file://)
            if (status == 0 || status == 200) {
              data = this.responseText;
            }
          });
          xhr.overrideMimeType('text/plain');
          xhr.send();
        }
        catch (e) {
          status = 0;
        }
        // assume that no data in local file mode means it doesn't exist
        if (status == 404 || (status == 0 && data == '')) {
          throw #{IOError.new `'No such file or directory: ' + path`};
        }
        return data;
      )
    # NOTE we're assuming standalone is SpiderMonkey
    when 'standalone'
      %x(return read(path);)
    else
      ''
    end
  end
end
