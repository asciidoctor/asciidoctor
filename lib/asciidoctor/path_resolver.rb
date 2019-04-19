# frozen_string_literal: true
module Asciidoctor
# Public: Handles all operations for resolving, cleaning and joining paths.
# This class includes operations for handling both web paths (request URIs) and
# system paths.
#
# The main emphasis of the class is on creating clean and secure paths. Clean
# paths are void of duplicate parent and current directory references in the
# path name. Secure paths are paths which are restricted from accessing
# directories outside of a jail path, if specified.
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
#       resolver.system_path('../../../css', '../../..', '/path/to/docs', recover: false)
#     rescue SecurityError => e
#       puts e.message
#     end
#     => 'path ../../../../../../css refers to location outside jail: /path/to/docs (disallowed in safe mode)'
#
#     resolver.system_path('/path/to/docs/images', nil, '/path/to/docs')
#     => '/path/to/docs/images'
#
#     begin
#       resolver.system_path('images', '/etc', '/path/to/docs', recover: false)
#     rescue SecurityError => e
#       puts e.message
#     end
#     => start path /etc is outside of jail: /path/to/docs'
#
class PathResolver
  include Logging

  DOT = '.'
  DOT_DOT = '..'
  DOT_SLASH = './'
  SLASH = '/'
  BACKSLASH = '\\'
  DOUBLE_SLASH = '//'
  WindowsRootRx = /^(?:[a-zA-Z]:)?[\\\/]/

  attr_accessor :file_separator
  attr_accessor :working_dir

  # Public: Construct a new instance of PathResolver, optionally specifying the
  # file separator (to override the system default) and the working directory
  # (to override the present working directory). The working directory will be
  # expanded to an absolute path inside the constructor.
  #
  # file_separator - the String file separator to use for path operations
  #                  (optional, default: File::ALT_SEPARATOR or File::SEPARATOR)
  # working_dir    - the String working directory (optional, default: Dir.pwd)
  #
  def initialize file_separator = nil, working_dir = nil
    @file_separator = file_separator || ::File::ALT_SEPARATOR || ::File::SEPARATOR
    @working_dir = working_dir ? ((root? working_dir) ? (posixify working_dir) : (::File.expand_path working_dir)) : ::Dir.pwd
    @_partition_path_sys = {}
    @_partition_path_web = {}
  end

  # Public: Check whether the specified path is an absolute path.
  #
  # This operation considers both posix paths and Windows paths. The path does
  # not have to be posixified beforehand. This operation does not handle URIs.
  #
  # Unix absolute paths start with a slash. UNC paths can start with a slash or
  # backslash. Windows roots can start with a drive letter.
  #
  # path - the String path to check
  #
  # returns a Boolean indicating whether the path is an absolute root path
  def absolute_path? path
    (path.start_with? SLASH) || (@file_separator == BACKSLASH && (WindowsRootRx.match? path))
  end

  # Public: Check if the specified path is an absolute root path (or, in the
  # browser environment, an absolute URI as well)
  #
  # This operation considers both posix paths and Windows paths. If the JavaScript IO
  # module is xmlhttprequest, this operation also considers absolute URIs.
  #
  # Unix absolute paths and UNC paths start with slash. Windows roots can
  # start with a drive letter. When the IO module is xmlhttprequest (Opal
  # runtime only), an absolute (qualified) URI (starts with file://, http://,
  # or https://) is also considered to be an absolute path.
  #
  # path - the String path to check
  #
  # returns a Boolean indicating whether the path is an absolute root path (or
  # an absolute URI when the JavaScript IO module is xmlhttprequest)
  if RUBY_ENGINE == 'opal' && ::JAVASCRIPT_IO_MODULE == 'xmlhttprequest'
    def root? path
      (absolute_path? path) || (path.start_with? 'file://', 'http://', 'https://')
    end
  else
    alias root? absolute_path?
  end

  # Public: Determine if the path is a UNC (root) path
  #
  # path - the String path to check
  #
  # returns a Boolean indicating whether the path is a UNC path
  def unc? path
    path.start_with? DOUBLE_SLASH
  end

  # Public: Determine if the path is an absolute (root) web path
  #
  # path - the String path to check
  #
  # returns a Boolean indicating whether the path is an absolute (root) web path
  def web_root? path
    path.start_with? SLASH
  end

  # Public: Determine whether path descends from base.
  #
  # If path equals base, or base is a parent of path, return true.
  #
  # path - The String path to check. Can be relative.
  # base - The String base path to check against. Can be relative.
  #
  # returns If path descends from base, return the offset, otherwise false.
  def descends_from? path, base
    if base == path
      0
    elsif base == SLASH
      (path.start_with? SLASH) && 1
    else
      (path.start_with? base + SLASH) && (base.length + 1)
    end
  end

  # Public: Calculate the relative path to this absolute path from the specified base directory
  #
  # If neither path or base are absolute paths, the path is not contained
  # within the base directory, or the relative path cannot be computed, the
  # original path is returned work is done.
  #
  # path - [String] an absolute filename.
  # base - [String] an absolute base directory.
  #
  # Return the [String] relative path of the specified path calculated from the base directory.
  def relative_path path, base
    if root? path
      if (offset = descends_from? path, base)
        path.slice offset, path.length
      else
        begin
          (Pathname.new path).relative_path_from(Pathname.new base).to_s
        rescue
          path
        end
      end
    else
      path
    end
  end

  # Public: Normalize path by converting any backslashes to forward slashes
  #
  # path - the String path to normalize
  #
  # returns a String path with any backslashes replaced with forward slashes
  def posixify path
    if path
      @file_separator == BACKSLASH && (path.include? BACKSLASH) ? (path.tr BACKSLASH, SLASH) : path
    else
      ''
    end
  end
  alias posixfy posixify

  # Public: Expand the specified path by converting the path to a posix path, resolving parent
  # references (..), and removing self references (.).
  #
  # path - the String path to expand
  #
  # returns a String path as a posix path with parent references resolved and self references removed.
  # The result will be relative if the path is relative and absolute if the path is absolute.
  def expand_path path
    path_segments, path_root = partition_path path
    if path.include? DOT_DOT
      resolved_segments = []
      path_segments.each do |segment|
        segment == DOT_DOT ? resolved_segments.pop : resolved_segments << segment
      end
      join_path resolved_segments, path_root
    else
      join_path path_segments, path_root
    end
  end

  # Public: Partition the path into path segments and remove self references (.) and the trailing
  # slash, if present. Prior to being partitioned, the path is converted to a posix path.
  #
  # Parent references are not resolved by this method since the consumer often needs to handle this
  # resolution in a certain context (checking for the breach of a jail, for instance).
  #
  # path - the String path to partition
  # web  - a Boolean indicating whether the path should be handled
  #        as a web path (optional, default: false)
  #
  # Returns a 2-item Array containing the Array of String path segments and the
  # path root (e.g., '/', './', 'c:/', or '//'), which is nil unless the path is absolute.
  def partition_path path, web = nil
    if (result = (cache = web ? @_partition_path_web : @_partition_path_sys)[path])
      return result
    end

    posix_path = posixify path

    if web
      # ex. /sample/path
      if web_root? posix_path
        root = SLASH
      # ex. ./sample/path
      elsif posix_path.start_with? DOT_SLASH
        root = DOT_SLASH
      # else ex. sample/path
      end
    elsif root? posix_path
      # ex. //sample/path
      if unc? posix_path
        root = DOUBLE_SLASH
      # ex. /sample/path
      elsif posix_path.start_with? SLASH
        root = SLASH
      # ex. C:/sample/path (or file:///sample/path in browser environment)
      else
        root = posix_path.slice 0, (posix_path.index SLASH) + 1
      end
    # ex. ./sample/path
    elsif posix_path.start_with? DOT_SLASH
      root = DOT_SLASH
    # else ex. sample/path
    end

    path_segments = (root ? (posix_path.slice root.length, posix_path.length) : posix_path).split SLASH
    # strip out all dot entries
    path_segments.delete DOT
    cache[path] = [path_segments, root]
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
    root ? %(#{root}#{segments.join SLASH}) : (segments.join SLASH)
  end

  # Public: Securely resolve a system path
  #
  # Resolve a system path from the target relative to the start path, jail path, or working
  # directory (specified in the constructor), in that order. If a jail path is specified, enforce
  # that the resolved path descends from the jail path. If a jail path is not provided, the resolved
  # path may be any location on the system. If the resolved path is absolute, use it as is (unless
  # it breaches the jail path). Expand all parent and self references in the resolved path.
  #
  # target - the String target path
  # start  - the String start path from which to resolve a relative target; falls back to jail, if
  #          specified, or the working directory specified in the constructor (default: nil)
  # jail   - the String jail path to which to confine the resolved path, if specified; must be an
  #          absolute path (default: nil)
  # opts   - an optional Hash of options to control processing (default: {}):
  #          * :recover is used to control whether the processor should
  #            automatically recover when an illegal path is encountered
  #          * :target_name is used in messages to refer to the path being resolved
  #
  # returns a String path relative to the start path, if specified, and confined to the jail path,
  # if specified. The path is posixified and all parent and self references in the path are expanded.
  def system_path target, start = nil, jail = nil, opts = {}
    if jail
      raise ::SecurityError, %(Jail is not an absolute path: #{jail}) unless root? jail
      #raise ::SecurityError, %(Jail is not a canonical path: #{jail}) if jail.include? DOT_DOT
      jail = posixify jail
    end

    if target
      if root? target
        target_path = expand_path target
        if jail && !(descends_from? target_path, jail)
          if opts.fetch :recover, true
            logger.warn %(#{opts[:target_name] || 'path'} is outside of jail; recovering automatically)
            target_segments, _ = partition_path target_path
            jail_segments, jail_root = partition_path jail
            return join_path jail_segments + target_segments, jail_root
          else
            raise ::SecurityError, %(#{opts[:target_name] || 'path'} #{target} is outside of jail: #{jail} (disallowed in safe mode))
          end
        end
        return target_path
      else
        target_segments, _ = partition_path target
      end
    else
      target_segments = []
    end

    if target_segments.empty?
      if start.nil_or_empty?
        return jail || @working_dir
      elsif root? start
        if jail
          start = posixify start
        else
          return expand_path start
        end
      else
        target_segments, _ = partition_path start
        start = jail || @working_dir
      end
    elsif start.nil_or_empty?
      start = jail || @working_dir
    elsif root? start
      start = posixify start if jail
    else
      #start = system_path start, jail, jail, opts
      start = %(#{(jail || @working_dir).chomp '/'}/#{start})
    end

    # both jail and start have been posixified at this point if jail is set
    if jail && (recheck = !(descends_from? start, jail)) && @file_separator == BACKSLASH
      start_segments, start_root = partition_path start
      jail_segments, jail_root = partition_path jail
      if start_root != jail_root
        if opts.fetch :recover, true
          logger.warn %(start path for #{opts[:target_name] || 'path'} is outside of jail root; recovering automatically)
          start_segments = jail_segments
          recheck = false
        else
          raise ::SecurityError, %(start path for #{opts[:target_name] || 'path'} #{start} refers to location outside jail root: #{jail} (disallowed in safe mode))
        end
      end
    else
      start_segments, jail_root = partition_path start
    end

    if (resolved_segments = start_segments + target_segments).include? DOT_DOT
      unresolved_segments, resolved_segments = resolved_segments, []
      if jail
        jail_segments, _ = partition_path jail unless jail_segments
        warned = false
        unresolved_segments.each do |segment|
          if segment == DOT_DOT
            if resolved_segments.size > jail_segments.size
              resolved_segments.pop
            elsif opts.fetch :recover, true
              unless warned
                logger.warn %(#{opts[:target_name] || 'path'} has illegal reference to ancestor of jail; recovering automatically)
                warned = true
              end
            else
              raise ::SecurityError, %(#{opts[:target_name] || 'path'} #{target} refers to location outside jail: #{jail} (disallowed in safe mode))
            end
          else
            resolved_segments << segment
          end
        end
      else
        unresolved_segments.each do |segment|
          segment == DOT_DOT ? resolved_segments.pop : resolved_segments << segment
        end
      end
    end

    if recheck
      target_path = join_path resolved_segments, jail_root
      if descends_from? target_path, jail
        target_path
      elsif opts.fetch :recover, true
        logger.warn %(#{opts[:target_name] || 'path'} is outside of jail; recovering automatically)
        jail_segments, _ = partition_path jail unless jail_segments
        join_path jail_segments + target_segments, jail_root
      else
        raise ::SecurityError, %(#{opts[:target_name] || 'path'} #{target} is outside of jail: #{jail} (disallowed in safe mode))
      end
    else
      join_path resolved_segments, jail_root
    end
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

    unless start.nil_or_empty? || (web_root? target)
      target, uri_prefix = extract_uri_prefix %(#{start}#{(start.end_with? SLASH) ? '' : SLASH}#{target})
    end

    # use this logic instead if we want to normalize target if it contains a URI
    #unless web_root? target
    #  target, uri_prefix = extract_uri_prefix target if preserve_uri_target
    #  target, uri_prefix = extract_uri_prefix %(#{start}#{SLASH}#{target}) unless uri_prefix || start.nil_or_empty?
    #end

    target_segments, target_root = partition_path target, true
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

  private

  # Internal: Efficiently extracts the URI prefix from the specified String if the String is a URI
  #
  # Uses the Asciidoctor::UriSniffRx regex to match the URI prefix in the specified String (e.g., http://). If present,
  # the prefix is removed.
  #
  # str - the String to check
  #
  # returns a tuple containing the specified string without the URI prefix, if present, and the extracted URI prefix.
  def extract_uri_prefix str
    if (str.include? ':') && UriSniffRx =~ str
      [(str.slice $&.length, str.length), $&]
    else
      str
    end
  end
end
end
