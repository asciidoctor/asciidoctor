# encoding: UTF-8
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
  DOT_SLASH = './'
  SLASH = '/'
  BACKSLASH = '\\'
  DOUBLE_SLASH = '//'
  WindowsRootRx = /^[a-zA-Z]:(?:\\|\/)/

  attr_accessor :file_separator
  attr_accessor :working_dir

  # Public: Construct a new instance of PathResolver, optionally specifying the
  # file separator (to override the system default) and the working directory
  # (to override the present working directory). The working directory will be
  # expanded to an absolute path inside the constructor.
  #
  # file_separator - the String file separator to use for path operations
  #                  (optional, default: File::SEPARATOR)
  # working_dir    - the String working directory (optional, default: Dir.pwd)
  #
  def initialize file_separator = nil, working_dir = nil
    @file_separator = file_separator ? file_separator : (::File::ALT_SEPARATOR || ::File::SEPARATOR)
    if working_dir
      @working_dir = (is_root? working_dir) ? working_dir : (::File.expand_path working_dir)
    else
      @working_dir = ::File.expand_path ::Dir.pwd
    end
    @_partition_path_sys, @_partition_path_web = {}, {}
  end

  # Public: Check if the specified path is an absolute root path.
  # This operation considers posix paths, windows paths, and file URLs.
  #
  # Unix absolute paths and UNC paths start with slash. Windows roots can start
  # with a drive letter. Absolute paths in the browser start with file://.
  #
  # path - the String path to check
  #
  # returns a Boolean indicating whether the path is an absolute root path
  if RUBY_ENGINE == 'opal'
    def is_root? path
      (path.start_with? SLASH) ||
          (::JAVASCRIPT_IO_MODULE == 'xmlhttprequest' && (path.start_with? 'file://')) ||
          (@file_separator == BACKSLASH && (WindowsRootRx.match? path))
    end
  else
    def is_root? path
      (path.start_with? SLASH) || (@file_separator == BACKSLASH && (WindowsRootRx.match? path))
    end
  end

  # Public: Determine if the path is a UNC (root) path
  #
  # path - the String path to check
  #
  # returns a Boolean indicating whether the path is a UNC path
  def is_unc? path
    path.start_with? DOUBLE_SLASH
  end

  # Public: Determine if the path is an absolute (root) web path
  #
  # path - the String path to check
  #
  # returns a Boolean indicating whether the path is an absolute (root) web path
  def is_web_root? path
    path.start_with? SLASH
  end

  # Public: Normalize path by converting any backslashes to forward slashes
  #
  # path - the String path to normalize
  #
  # returns a String path with any backslashes replaced with forward slashes
  def posixify path
    if path.nil_or_empty?
      ''
    elsif path.include? BACKSLASH
      path.tr BACKSLASH, SLASH
    else
      path
    end
  end
  alias posixfy posixify

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
  def expand_path path
    path_segments, path_root, _ = partition_path path
    join_path path_segments, path_root
  end

  # Public: Partition the path into path segments and remove any empty segments
  # or segments that are self references (.). The path is converted to a posix
  # path before being partitioned.
  #
  # path - the String path to partition
  # web  - a Boolean indicating whether the path should be handled
  #        as a web path (optional, default: false)
  #
  # Returns a 3-item Array containing the Array of String path segments, the
  # path root (e.g., '/', './', 'c:/') if the path is absolute and the posix
  # version of the path.
  #--
  # QUESTION is it worth it to normalize slashes? it doubles the time elapsed
  def partition_path path, web = nil
    if (result = (cache = web ? @_partition_path_web : @_partition_path_sys)[path])
      return result
    end

    posix_path = posixify path

    root = if web
      # ex. /sample/path
      if is_web_root? posix_path
        SLASH
      # ex. ./sample/path
      elsif posix_path.start_with? DOT_SLASH
        DOT_SLASH
      # ex. sample/path
      else
        nil
      end
    else
      if is_root? posix_path
        # ex. //sample/path
        if is_unc? posix_path
          DOUBLE_SLASH
        # ex. /sample/path
        elsif posix_path.start_with? SLASH
          SLASH
        # ex. C:/sample/path (or file:///sample/path in browser environment)
        else
          posix_path.slice 0, (posix_path.index SLASH) + 1
        end
      # ex. ./sample/path
      elsif posix_path.start_with? DOT_SLASH
        DOT_SLASH
      # ex. sample/path
      else
        nil
      end
    end

    path_segments = posix_path.split SLASH
    # shift twice for a UNC path
    if root == DOUBLE_SLASH
      path_segments = path_segments[2..-1]
    # shift twice for a file:/// path and adjust root
    # NOTE technically file:/// paths work without this adjustment
    #elsif ::RUBY_ENGINE_OPAL && ::JAVASCRIPT_IO_MODULE == 'xmlhttprequest' && root == 'file:/'
    #  root = 'file://'
    #  path_segments = path_segments[2..-1]
    # shift once for any other root
    elsif root
      path_segments.shift
    end
    # strip out all dot entries
    path_segments.delete DOT
    # QUESTION should we chop trailing /? (we pay a small fraction)
    #posix_path = posix_path.chop if posix_path.end_with? SLASH
    cache[path] = [path_segments, root, posix_path]
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
  def join_path segments, root = nil
    root ? %(#{root}#{segments * SLASH}) : segments * SLASH
  end

  # Public: Resolve a system path from the target and start paths. If a jail
  # path is specified, enforce that the resolved directory is contained within
  # the jail path. If a jail path is not provided, the resolved path may be
  # any location on the system. If the resolved path is absolute, use it as is.
  # If the resolved path is relative, resolve it relative to the working_dir
  # specified in the constructor.
  #
  # target - the String target path
  # start  - the String start (i.e., parent) path (default: nil)
  # jail   - the String jail path to confine the resolved path (default: nil)
  # opts   - an optional Hash of options to control processing (default: {}):
  #          * :recover is used to control whether the processor should auto-recover
  #              when an illegal path is encountered
  #          * :target_name is used in messages to refer to the path being resolved
  #
  # returns a String path that joins the target path with the start path with
  # any parent references resolved and self references removed and enforces
  # that the resolved path be contained within the jail, if provided
  def system_path target, start = nil, jail = nil, opts = {}
    if jail
      unless is_root? jail
        raise ::SecurityError, %(Jail is not an absolute path: #{jail})
      end
      jail = posixify jail
    end

    if target.nil_or_empty?
      target_segments = []
    else
      target_segments, target_root, _ = partition_path target
    end

    if target_segments.empty?
      if start.nil_or_empty?
        return jail ? jail : @working_dir
      elsif is_root? start
        unless jail
          return expand_path start
        end
      else
        return system_path start, jail, jail, opts
      end
    end

    if target_root && target_root != DOT_SLASH
      resolved_target = join_path target_segments, target_root
      # if target is absolute and a sub-directory of jail, or
      # a jail is not in place, let it slide
      if !jail || (resolved_target.start_with? jail)
        return resolved_target
      end
    end

    if start.nil_or_empty?
      start = jail ? jail : @working_dir
    elsif is_root? start
      start = posixify start
    else
      start = system_path start, jail, jail, opts
    end

    # both jail and start have been posixfied at this point
    if jail == start
      jail_segments, jail_root, _ = partition_path jail
      start_segments = jail_segments.dup
    elsif jail
      unless start.start_with? jail
        raise ::SecurityError, %(#{opts[:target_name] || 'Start path'} #{start} is outside of jail: #{jail} (disallowed in safe mode))
      end

      start_segments, start_root, _ = partition_path start
      jail_segments, jail_root, _ = partition_path jail

      # Already checked for this condition
      #if start_root != jail_root
      #  raise ::SecurityError, %(Jail root #{jail_root} does not match root of #{opts[:target_name] || 'start path'}: #{start_root})
      #end
    else
      start_segments, start_root, _ = partition_path start
      jail_root = start_root
    end

    resolved_segments = start_segments.dup
    warned = false
    target_segments.each do |segment|
      if segment == DOT_DOT
        if jail
          if resolved_segments.size > jail_segments.size
            resolved_segments.pop
          elsif !(recover ||= (opts.fetch :recover, true))
            raise ::SecurityError, %(#{opts[:target_name] || 'path'} #{target} refers to location outside jail: #{jail} (disallowed in safe mode))
          elsif !warned
            warn %(asciidoctor: WARNING: #{opts[:target_name] || 'path'} has illegal reference to ancestor of jail, auto-recovering)
            warned = true
          end
        else
          resolved_segments.pop
        end
      else
        resolved_segments << segment
      end
    end

    join_path resolved_segments, jail_root
  end

  # Public: Resolve a web path from the target and start paths.
  # The main function of this operation is to resolve any parent
  # references and remove any self references.
  #
  # The target is assumed to be a path, not a qualified URI.
  # That check should happen before this method is invoked.
  #
  # target - the String target path
  # start  - the String start (i.e., parent) path
  #
  # returns a String path that joins the target path with the
  # start path with any parent references resolved and self
  # references removed
  def web_path target, start = nil
    target = posixify target
    start = posixify start
    uri_prefix = nil

    unless start.nil_or_empty? || (is_web_root? target)
      target = (start.end_with? SLASH) ? %(#{start}#{target}) : %(#{start}#{SLASH}#{target})
      if (uri_prefix = Helpers.uri_prefix target)
        target = target[uri_prefix.length..-1]
      end
    end

    # use this logic instead if we want to normalize target if it contains a URI
    #unless is_web_root? target
    #  if preserve_uri_target && (uri_prefix = Helpers.uri_prefix target)
    #    target = target[uri_prefix.length..-1]
    #  elsif !start.nil_or_empty?
    #    target = %(#{start}#{SLASH}#{target})
    #    if (uri_prefix = Helpers.uri_prefix target)
    #      target = target[uri_prefix.length..-1]
    #    end
    #  end
    #end

    target_segments, target_root, _ = partition_path target, true
    resolved_segments = []
    target_segments.each do |segment|
      if segment == DOT_DOT
        if resolved_segments.empty?
          resolved_segments << segment unless target_root && target_root != DOT_SLASH
        elsif resolved_segments[-1] == DOT_DOT
          resolved_segments << segment
        else
          resolved_segments.pop
        end
      else
        resolved_segments << segment
        # checking for empty would eliminate repeating forward slashes
        #resolved_segments << segment unless segment.empty?
      end
    end

    if (resolved_path = join_path resolved_segments, target_root).include? ' '
      resolved_path = resolved_path.gsub ' ', '%20'
    end

    uri_prefix ? %(#{uri_prefix}#{resolved_path}) : resolved_path
  end

  # Public: Calculate the relative path to this absolute filename from the specified base directory
  #
  # If either the filename or the base_directory are not absolute paths, or the
  # filename is not contained within the base directory, no work is done.
  #
  # filename       - [String] an absolute filename.
  # base_directory - [String] an absolute base directory.
  #
  # Return the [String] relative path of the filename calculated from the base directory.
  def relative_path filename, base_directory
    if (is_root? filename) && (filename.start_with? base_directory)
      filename.slice base_directory.length + 1, filename.length
    else
      filename
    end
  end
end
end
