module Asciidoctor
# Public: Handles all operations for resolving, cleaning and joining paths.
# This class includes operations for handling both web paths (request URIs) and
# system paths.
#
# The main emphasis of the class is on creating clean and secure paths. Clean
# paths are void of duplicate parent and current directory references in the
# path name. Secure paths are paths which are restricted from accessing
# directories outside of a jail root, if specified.
#
# Since joining two paths can result in an insecure path, this class also
# handles the task of joining a parent (start) and child (target) path.
#
# This class makes no use of path utilities from the Ruby libraries. Instead,
# it handles all aspects of path manipulation. The main benefit of
# internalizing these operations is that the class is able to handle both posix
# and windows paths independent of the operating system on which it runs. This
# makes the class both deterministic and easier to test.
#
# Examples
#
#     resolver = PathResolver.new
#
#     # Web Paths
#
#     resolver.web_path('images')
#     => 'images'
#
#     resolver.web_path('./images')
#     => './images'
#
#     resolver.web_path('/images')
#     => '/images'
#
#     resolver.web_path('./images/../assets/images')
#     => './assets/images'
#
#     resolver.web_path('/../images')
#     => '/images'
#
#     resolver.web_path('images', 'assets')
#     => 'assets/images'
#
#     resolver.web_path('tiger.png', '../assets/images')
#     => '../assets/images/tiger.png'
#
#     # System Paths
#
#     resolver.working_dir
#     => '/path/to/docs'
#
#     resolver.system_path('images')
#     => '/path/to/docs/images'
#
#     resolver.system_path('../images')
#     => '/path/to/images'
#
#     resolver.system_path('/etc/images')
#     => '/etc/images'
#
#     resolver.system_path('images', '/etc')
#     => '/etc/images'
#
#     resolver.system_path('', '/etc/images')
#     => '/etc/images'
#
#     resolver.system_path(nil, nil, '/path/to/docs')
#     => '/path/to/docs'
#
#     resolver.system_path('..', nil, '/path/to/docs')
#     => '/path/to/docs'
#
#     resolver.system_path('../../../css', nil, '/path/to/docs')
#     => '/path/to/docs/css'
#
#     resolver.system_path('../../../css', '../../..', '/path/to/docs')
#     => '/path/to/docs/css'
#
#     resolver.system_path('..', 'C:\\data\\docs\\assets', 'C:\\data\\docs')
#     => 'C:/data/docs'
#
#     resolver.system_path('..\\..\\css', 'C:\\data\\docs\\assets', 'C:\\data\\docs')
#     => 'C:/data/docs/css'
#
#     begin
#       resolver.system_path('../../../css', '../../..', '/path/to/docs', :recover => false)
#     rescue SecurityError => e
#       puts e.message
#     end
#     => 'path ../../../../../../css refers to location outside jail: /path/to/docs (disallowed in safe mode)'
#
#     resolver.system_path('/path/to/docs/images', nil, '/path/to/docs')
#     => '/path/to/docs/images'
#
#     begin
#       resolver.system_path('images', '/etc', '/path/to/docs')
#     rescue SecurityError => e
#       puts e.message 
#     end
#     => Start path /etc is outside of jail: /path/to/docs'
#
class PathResolver
  DOT = '.'
  DOT_DOT = '..'
  SLASH = '/'
  BACKSLASH = '\\'
  WIN_ROOT_RE = /^[[:alpha:]]:(?:\\|\/)/

  attr_accessor :file_separator
  attr_accessor :working_dir

  # Public: Construct a new instance of PathResolver, optionally specifying the
  # file separator (to override the system default) and the working directory
  # (to override the present working directory). The working directory will be
  # expanded to an absolute path inside the constructor.
  #
  # file_separator - the String file separator to use for path operations
  #                  (optional, default: File::FILE_SEPARATOR)
  # working_dir    - the String working directory (optional, default: Dir.pwd)
  #
  def initialize(file_separator = nil, working_dir = nil)
    @file_separator = file_separator.nil? ? (File::ALT_SEPARATOR || File::SEPARATOR) : file_separator
    if working_dir.nil?
      @working_dir = File.expand_path(Dir.pwd)
    else
      @working_dir = is_root?(working_dir) ? working_dir : File.expand_path(working_dir) 
    end
  end

  # Public: Check if the specified path is an absolute root path
  # This operation correctly handles both posix and windows paths.
  #
  # path - the String path to check
  #
  # returns a Boolean indicating whether the path is an absolute root path
  def is_root?(path)
    if @file_separator == BACKSLASH && path.match(WIN_ROOT_RE)
      true
    elsif path.start_with? SLASH
      true
    else
      false
    end
  end

  # Public: Determine if the path is an absolute (root) web path
  #
  # path - the String path to check
  #
  # returns a Boolean indicating whether the path is an absolute (root) web path
  def is_web_root?(path)
    path.start_with? SLASH
  end
  
  # Public: Normalize path by converting any backslashes to forward slashes
  #
  # path - the String path to normalize
  #
  # returns a String path with any backslashes replaced with forward slashes
  def posixfy(path)
    return '' if path.to_s.empty?
    path.include?(BACKSLASH) ? path.tr(BACKSLASH, SLASH) : path
  end

  # Public: Expand the path by resolving any parent references (..)
  # and cleaning self references (.).
  #
  # The result will be relative if the path is relative and
  # absolute if the path is absolute. The file separator used
  # in the expanded path is the one specified when the class
  # was constructed.
  #
  # path - the String path to expand
  #
  # returns a String path with any parent or self references resolved.
  def expand_path(path)
    path_segments, path_root, _ = partition_path(path)
    join_path path_segments, path_root
  end
  
  # Public: Partition the path into path segments and remove any empty segments
  # or segments that are self references (.). The path is split on either posix
  # or windows file separators.
  #
  # path     - the String path to partition
  # web_path - a Boolean indicating whether the path should be handled
  #            as a web path (optional, default: false)
  #
  # returns a 3-item Array containing the Array of String path segments, the
  # path root, if the path is absolute, and the posix version of the path.
  def partition_path(path, web_path = false)
    posix_path = posixfy path
    is_root = web_path ? is_web_root?(posix_path) : is_root?(posix_path)
    path_segments = posix_path.tr_s(SLASH, SLASH).split(SLASH)
    # capture relative root
    root = path_segments.first == DOT ? DOT : nil
    path_segments.delete(DOT)
    # capture absolute root, preserving relative root if set
    root = is_root ? path_segments.shift : root
  
    [path_segments, root, posix_path]
  end
  
  # Public: Join the segments using the posix file separator (since Ruby knows
  # how to work with paths specified this way, regardless of OS). Use the root,
  # if specified, to construct an absolute path. Otherwise join the segments as
  # a relative path.
  #
  # segments - a String Array of path segments
  # root     - a String path root (optional, default: nil)
  #
  # returns a String path formed by joining the segments using the posix file
  # separator and prepending the root, if specified
  def join_path(segments, root = nil)
    if root
      "#{root}#{SLASH}#{segments * SLASH}"
    else
      segments * SLASH
    end
  end
  
  # Public: Resolve a system path from the target and start paths. If a jail
  # path is specified, enforce that the resolved directory is contained within
  # the jail path. If a jail path is not provided, the resolved path may be
  # any location on the system. If the resolved path is absolute, use it as is.
  # If the resolved path is relative, resolve it relative to the working_dir
  # specified in the constructor.
  #
  # target - the String target path
  # start  - the String start (i.e., parent) path
  # jail   - the String jail path to confine the resolved path
  # opts   - an optional Hash of options to control processing (default: {}):
  #          * :recover is used to control whether the processor should auto-recover
  #              when an illegal path is encountered
  #          * :target_name is used in messages to refer to the path being resolved
  #
  # returns a String path that joins the target path with the start path with
  # any parent references resolved and self references removed and enforces
  # that the resolved path be contained within the jail, if provided
  def system_path(target, start, jail = nil, opts = {})
    recover = opts.fetch(:recover, true)
    unless jail.nil?
      unless is_root? jail
        raise SecurityError, "Jail is not an absolute path: #{jail}"
      end
      jail = posixfy jail
    end

    if target.to_s.empty?
      target_segments = []
    else
      target_segments, target_root, _ = partition_path(target)
    end

    if target_segments.empty?
      if start.to_s.empty?
        return jail.nil? ? @working_dir : jail
      elsif is_root? start
        if jail.nil?
          return expand_path start
        end
      else
        return system_path(start, jail, jail)
      end
    end
  
    if target_root && target_root != DOT
      resolved_target = join_path target_segments, target_root
      # if target is absolute and a sub-directory of jail, or
      # a jail is not in place, let it slide
      if jail.nil? || resolved_target.start_with?(jail)
        return resolved_target
      end
    end
  
    if start.to_s.empty?
      start = jail.nil? ? @working_dir : jail
    elsif is_root? start
      start = posixfy start
    else
      start = system_path(start, jail, jail)
    end
  
    # both jail and start have been posixfied at this point
    if jail == start
      jail_segments, jail_root, _ = partition_path(jail)
      start_segments = jail_segments.dup
    elsif !jail.nil?
      if !start.start_with?(jail)
        raise SecurityError, "#{opts[:target_name] || 'Start path'} #{start} is outside of jail: #{jail} (disallowed in safe mode)"
      end

      start_segments, start_root, _ = partition_path(start)
      jail_segments, jail_root, _ = partition_path(jail)
  
      # Already checked for this condition
      #if start_root != jail_root
      #  raise SecurityError, "Jail root #{jail_root} does not match root of #{opts[:target_name] || 'start path'}: #{start_root}"
      #end
    else
      start_segments, start_root, _ = partition_path(start)
      jail_root = start_root
    end
  
    resolved_segments = start_segments.dup
    warned = false
    target_segments.each do |segment|
      if segment == DOT_DOT
        if !jail.nil?
          if resolved_segments.length > jail_segments.length
            resolved_segments.pop
          elsif !recover
            raise SecurityError, "#{opts[:target_name] || 'path'} #{target} refers to location outside jail: #{jail} (disallowed in safe mode)"
          elsif !warned
            warn "asciidoctor: WARNING: #{opts[:target_name] || 'path'} has illegal reference to ancestor of jail, auto-recovering"
            warned = true
          end
        else
          resolved_segments.pop
        end
      else
        resolved_segments.push segment
      end
    end
  
    join_path resolved_segments, jail_root
  end

  # Public: Resolve a web path from the target and start paths.
  # The main function of this operation is to resolve any parent
  # references and remove any self references.
  #
  # target - the String target path
  # start  - the String start (i.e., parent) path
  #
  # returns a String path that joins the target path with the
  # start path with any parent references resolved and self
  # references removed
  def web_path(target, start = nil)
    target = posixfy(target)
    start = posixfy(start)
    uri_prefix = nil

    unless is_web_root?(target) || start.empty?
      target = "#{start}#{SLASH}#{target}"
      if target.include?(':') && target.match(Asciidoctor::REGEXP[:uri_sniff])
        uri_prefix = $~[0]
        target = target[uri_prefix.length..-1]
      end
    end

    target_segments, target_root, _ = partition_path(target, true)
    resolved_segments = target_segments.inject([]) do |accum, segment|
      if segment == DOT_DOT
        if accum.empty?
          accum.push segment unless target_root && target_root != DOT
        elsif accum[-1] == DOT_DOT
          accum.push segment
        else
          accum.pop
        end
      else
        accum.push segment
      end
      accum
    end

    if uri_prefix.nil?
      join_path resolved_segments, target_root
    else
      "#{uri_prefix}#{join_path resolved_segments, target_root}"
    end
  end

  # Public: Calculate the relative path to this absolute filename from the specified base directory
  #
  # If either the filename or the base_directory are not absolute paths, no work is done.
  #
  # filename       - An absolute file name as a String
  # base_directory - An absolute base directory as a String
  #
  # Return the relative path String of the filename calculated from the base directory
  def relative_path(filename, base_directory)
    if (is_root? filename) && (is_root? base_directory)
      offset = base_directory.chomp(@file_separator).length + 1
      filename[offset..-1]
    else
      filename
    end
  end
end
end
