# encoding: UTF-8
module Asciidoctor
# Public: An abstract base class that provides state and methods for managing a
# node of AsciiDoc content. The state and methods on this class are comment to
# all content segments in an AsciiDoc document.
class AbstractNode

  include Substitutors

  # Public: Get the element which is the parent of this node
  attr_reader :parent

  # Public: Get the Asciidoctor::Document to which this node belongs
  attr_reader :document

  # Public: Get the Symbol context for this node
  attr_reader :context

  # Public: Get the String name of this node
  attr_reader :node_name

  # Public: Get/Set the id of this node
  attr_accessor :id

  # Public: Get the Hash of attributes for this node
  attr_reader :attributes

  def initialize parent, context, opts = {}
    # document is a special case, should refer to itself
    if context == :document
      @document = parent
    else
      if parent
        @parent = parent
        @document = parent.document
      else
        @parent = nil
        @document = nil
      end
    end
    @context = context
    @node_name = context.to_s
    # QUESTION are we correct in duplicating the attributes (seems to be just as fast)
    @attributes = (opts.key? :attributes) ? opts[:attributes].dup : {}
    @passthroughs = {}
  end

  # Public: Associate this Block with a new parent Block
  #
  # parent - The Block to set as the parent of this Block
  #
  # Returns nothing
  def parent=(parent)
    @parent = parent
    @document = parent.document
    nil
  end

  # Public: Returns whether this {AbstractNode} is an instance of {Inline}
  #
  # Returns [Boolean]
  def inline?
    # :nocov:
    raise ::NotImplementedError
    # :nocov:
  end

  # Public: Returns whether this {AbstractNode} is an instance of {Block}
  #
  # Returns [Boolean]
  def block?
    # :nocov:
    raise ::NotImplementedError
    # :nocov:
  end

  # Public: Get the value of the specified attribute
  #
  # Get the value for the specified attribute. First look in the attributes on
  # this node and return the value of the attribute if found. Otherwise, if
  # this node is a child of the Document node, look in the attributes of the
  # Document node and return the value of the attribute if found. Otherwise,
  # return the default value, which defaults to nil.
  #
  # name          - the String or Symbol name of the attribute to lookup
  # default_value - the Object value to return if the attribute is not found (default: nil)
  # inherit       - a Boolean indicating whether to check for the attribute on the
  #                 AsciiDoctor::Document if not found on this node (default: false)
  #
  # return the value of the attribute or the default value if the attribute
  # is not found in the attributes of this node or the document node
  def attr(name, default_value = nil, inherit = true)
    name = name.to_s if ::Symbol === name
    inherit = false if self == @document
    if inherit
      @attributes[name] || @document.attributes[name] || default_value
    else
      @attributes[name] || default_value
    end
  end

  # Public: Check if the attribute is defined, optionally performing a
  # comparison of its value if expected is not nil
  #
  # Check if the attribute is defined. First look in the attributes on this
  # node. If not found, and this node is a child of the Document node, look in
  # the attributes of the Document node. If the attribute is found and a
  # comparison value is specified (not nil), return whether the two values match.
  # Otherwise, return whether the attribute was found.
  #
  # name    - the String or Symbol name of the attribute to lookup
  # expect  - the expected Object value of the attribute (default: nil)
  # inherit - a Boolean indicating whether to check for the attribute on the
  #           AsciiDoctor::Document if not found on this node (default: false)
  #
  # return a Boolean indicating whether the attribute exists and, if a
  # comparison value is specified, whether the value of the attribute matches
  # the comparison value
  def attr?(name, expect = nil, inherit = true)
    name = name.to_s if ::Symbol === name
    inherit = false if self == @document
    if expect.nil?
      @attributes.has_key?(name) || (inherit && @document.attributes.has_key?(name))
    elsif inherit
      expect == (@attributes[name] || @document.attributes[name])
    else
      expect == @attributes[name]
    end
  end

  # Public: Assign the value to the attribute name for the current node.
  #
  # name      - The String attribute name to assign
  # value     - The Object value to assign to the attribute
  # overwrite - A Boolean indicating whether to assign the attribute
  #             if currently present in the attributes Hash (default: true)
  #
  # Returns a [Boolean] indicating whether the assignment was performed
  def set_attr name, value, overwrite = true
    if overwrite == false && (@attributes.key? name)
      false
    else
      @attributes[name] = value
      true
    end
  end

  # TODO document me
  def set_option(name)
    if @attributes.has_key? 'options'
      @attributes['options'] = "#{@attributes['options']},#{name}"
    else
      @attributes['options'] = name
    end
    @attributes["#{name}-option"] = ''
  end

  # Public: A convenience method to check if the specified option attribute is
  # enabled on the current node.
  #
  # Check if the option is enabled. This method simply checks to see if the
  # %name%-option attribute is defined on the current node.
  #
  # name    - the String or Symbol name of the option
  #
  # return a Boolean indicating whether the option has been specified
  def option?(name)
    @attributes.has_key? %(#{name}-option)
  end

  # Public: Update the attributes of this node with the new values in
  # the attributes argument.
  #
  # If an attribute already exists with the same key, it's value will
  # be overridden.
  #
  # attributes - A Hash of attributes to assign to this node.
  #
  # Returns nothing
  def update_attributes(attributes)
    @attributes.update(attributes)
    nil
  end

  # Public: Get the Asciidoctor::Converter instance being used to convert the
  # current Asciidoctor::Document.
  def converter
    @document.converter
  end

  # Public: A convenience method that checks if the role attribute is specified
  def role?(expect = nil)
    if expect
      expect == (@attributes['role'] || @document.attributes['role'])
    else
      @attributes.has_key?('role') || @document.attributes.has_key?('role')
    end
  end

  # Public: A convenience method that returns the value of the role attribute
  def role
    @attributes['role'] || @document.attributes['role']
  end

  # Public: A convenience method that checks if the specified role is present
  # in the list of roles on this node
  def has_role?(name)
    if (val = (@attributes['role'] || @document.attributes['role']))
      val.split(' ').include?(name)
    else
      false
    end
  end

  # Public: A convenience method that returns the role names as an Array
  def roles
    if (val = (@attributes['role'] || @document.attributes['role']))
      val.split(' ')
    else
      []
    end
  end

  # Public: A convenience method that adds the given role directly to this node
  def add_role(name)
    unless (roles = (@attributes['role'] || '').split(' ')).include? name
      @attributes['role'] = roles.push(name) * ' '
    end
  end

  # Public: A convenience method that removes the given role directly from this node
  def remove_role(name)
    if (roles = (@attributes['role'] || '').split(' ')).include? name
      roles.delete name
      @attributes['role'] = roles * ' '
    end
  end

  # Public: A convenience method that checks if the reftext attribute is specified
  def reftext?
    @attributes.has_key?('reftext') || @document.attributes.has_key?('reftext')
  end

  # Public: A convenience method that returns the value of the reftext attribute
  def reftext
    @attributes['reftext'] || @document.attributes['reftext']
  end

  # Public: Construct a reference or data URI to an icon image for the
  # specified icon name.
  #
  # If the 'icon' attribute is set on this block, the name is ignored and the
  # value of this attribute is used as the  target image path. Otherwise,
  # construct a target image path by concatenating the value of the 'iconsdir'
  # attribute, the icon name and the value of the 'icontype' attribute
  # (defaulting to 'png').
  #
  # The target image path is then passed through the #image_uri() method.  If
  # the 'data-uri' attribute is set on the document, the image will be
  # safely converted to a data URI.
  #
  # The return value of this method can be safely used in an image tag.
  #
  # name - The String name of the icon
  #
  # Returns A String reference or data URI for an icon image
  def icon_uri name
    if attr? 'icon'
      # QUESTION should we add extension if resolved value is an absolute URI?
      if ::File.extname(uri = (image_uri attr('icon'), 'iconsdir')).empty?
        %(#{uri}.#{@document.attr 'icontype', 'png'})
      else
        uri
      end
    else
      image_uri %(#{name}.#{@document.attr 'icontype', 'png'}), 'iconsdir'
    end
  end

  # Public: Construct a URI reference to the target media.
  #
  # If the target media is a URI reference, then leave it untouched.
  #
  # The target media is resolved relative to the directory retrieved from the
  # specified attribute key, if provided.
  #
  # The return value can be safely used in a media tag (img, audio, video).
  #
  # target        - A String reference to the target media
  # asset_dir_key - The String attribute key used to lookup the directory where
  #                 the media is located (default: 'imagesdir')
  #
  # Returns A String reference for the target media
  def media_uri(target, asset_dir_key = 'imagesdir')
    normalize_web_path target, (asset_dir_key ? @document.attr(asset_dir_key) : nil)
  end

  # Public: Construct a URI reference or data URI to the target image.
  #
  # If the target image is a URI reference, then leave it untouched.
  #
  # The target image is resolved relative to the directory retrieved from the
  # specified attribute key, if provided.
  #
  # If the 'data-uri' attribute is set on the document, and the safe mode level
  # is less than SafeMode::SECURE, the image will be safely converted to a data URI
  # by reading it from the same directory. If neither of these conditions
  # are satisfied, a relative path (i.e., URL) will be returned.
  #
  # The return value of this method can be safely used in an image tag.
  #
  # target_image - A String path to the target image
  # asset_dir_key - The String attribute key used to lookup the directory where
  #                the image is located (default: 'imagesdir')
  #
  # Returns A String reference or data URI for the target image
  def image_uri(target_image, asset_dir_key = 'imagesdir')
    if (doc = @document).safe < SafeMode::SECURE && doc.attr?('data-uri')
      if (Helpers.uriish? target_image) ||
          (asset_dir_key && (images_base = doc.attr(asset_dir_key)) && (Helpers.uriish? images_base) &&
          (target_image = normalize_web_path(target_image, images_base, false)))
        if doc.attr?('allow-uri-read')
          generate_data_uri_from_uri target_image, doc.attr?('cache-uri')
        else
          target_image
        end
      else
        generate_data_uri target_image, asset_dir_key
      end
    else
      normalize_web_path target_image, (asset_dir_key ? doc.attr(asset_dir_key) : nil)
    end
  end

  # Public: Generate a data URI that can be used to embed an image in the output document
  #
  # First, and foremost, the target image path is cleaned if the document safe mode level
  # is set to at least SafeMode::SAFE (a condition which is true by default) to prevent access
  # to ancestor paths in the filesystem. The image data is then read and converted to
  # Base64. Finally, a data URI is built which can be used in an image tag.
  #
  # target_image - A String path to the target image
  # asset_dir_key - The String attribute key used to lookup the directory where
  #                the image is located (default: nil)
  #
  # Returns A String data URI containing the content of the target image
  def generate_data_uri(target_image, asset_dir_key = nil)
    ext = ::File.extname target_image
    # QUESTION what if ext is empty?
    mimetype = (ext == '.svg' ? 'image/svg+xml' : %(image/#{ext[1..-1]}))
    if asset_dir_key
      image_path = normalize_system_path(target_image, @document.attr(asset_dir_key), nil, :target_name => 'image')
    else
      image_path = normalize_system_path(target_image)
    end

    unless ::File.readable? image_path
      warn %(asciidoctor: WARNING: image to embed not found or not readable: #{image_path})
      # must enclose string following return in " for Opal
      return "data:#{mimetype}:base64,"
      # uncomment to return 1 pixel white dot instead
      #return 'data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw=='
    end

    bindata = nil
    if ::IO.respond_to? :binread
      bindata = ::IO.binread(image_path)
    else
      bindata = ::File.open(image_path, 'rb') {|file| file.read }
    end
    # NOTE base64 is autoloaded by reference to ::Base64
    %(data:#{mimetype};base64,#{::Base64.encode64(bindata).delete EOL})
  end

  # Public: Read the image data from the specified URI and generate a data URI
  #
  # The image data is read from the URI and converted to Base64. A data URI is
  # constructed from the content_type header and Base64 data and returned,
  # which can then be used in an image tag.
  #
  # image_uri  - The URI from which to read the image data. Can be http://, https:// or ftp://
  # cache_uri  - A Boolean to control caching. When true, the open-uri-cached library
  #              is used to cache the image for subsequent reads. (default: false)
  #
  # Returns A data URI string built from Base64 encoded data read from the URI
  # and the mime type specified in the Content Type header.
  def generate_data_uri_from_uri image_uri, cache_uri = false
    if cache_uri
      # caching requires the open-uri-cached gem to be installed
      # processing will be automatically aborted if these libraries can't be opened
      Helpers.require_library 'open-uri/cached', 'open-uri-cached'
    elsif !::RUBY_ENGINE_OPAL
      # autoload open-uri
      ::OpenURI
    end

    begin
      mimetype = nil
      bindata = open(image_uri, 'rb') {|file|
        mimetype = file.content_type
        file.read
      }
      # NOTE base64 is autoloaded by reference to ::Base64
      %(data:#{mimetype};base64,#{::Base64.encode64(bindata).delete EOL})
    rescue
      warn %(asciidoctor: WARNING: could not retrieve image data from URI: #{image_uri})
      image_uri
      # uncomment to return empty data (however, mimetype needs to be resolved)
      #%(data:#{mimetype}:base64,)
      # uncomment to return 1 pixel white dot instead
      #'data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw=='
    end
  end

  # Public: Resolve the URI or system path to the specified target, then read and return its contents
  #
  # The URI or system path of the target is first resolved. If the resolved path is a URI, read the
  # contents from the URI if the allow-uri-read attribute is set, enabling caching if the cache-uri
  # attribute is also set. If the resolved path is not a URI, read the contents of the file from the
  # file system. If the normalize option is set, the data will be normalized.
  #
  # target - The URI or local path from which to read the data.
  # opts   - a Hash of options to control processing (default: {})
  #          * :label the String label of the target to use in warning messages (default: 'asset')
  #          * :normalize a Boolean that indicates whether the data should be normalized (default: false)
  #          * :start the String relative base path to use when resolving the target (default: nil)
  #          * :warn_on_failure a Boolean that indicates whether warnings are issued if the target cannot be read (default: true)
  # Returns the contents of the resolved target or nil if the resolved target cannot be read
  # --
  # TODO refactor other methods in this class to use this method were possible (repurposing if necessary)
  def read_contents target, opts = {}
    doc = @document
    if (Helpers.uriish? target) || ((start = opts[:start]) && (Helpers.uriish? start) &&
        (target = (@path_resolver ||= PathResolver.new).web_path target, start))
      if doc.attr? 'allow-uri-read'
        Helpers.require_library 'open-uri/cached', 'open-uri-cached' if doc.attr? 'cache-uri'
        begin
          data = ::OpenURI.open_uri(target) {|fd| fd.read }
          data = (Helpers.normalize_lines_from_string data) * EOL if opts[:normalize]
        rescue
          warn %(asciidoctor: WARNING: could not retrieve contents of #{opts[:label] || 'asset'} at URI: #{target}) if opts.fetch :warn_on_failure, true
          data = nil
        end
      else
        warn %(asciidoctor: WARNING: cannot retrieve contents of #{opts[:label] || 'asset'} at URI: #{target} (allow-uri-read attribute not enabled)) if opts.fetch :warn_on_failure, true
        data = nil
      end
    else
      target = normalize_system_path target, opts[:start], nil, :target_name => (opts[:label] || 'asset')
      data = read_asset target, :normalize => opts[:normalize], :warn_on_failure => (opts.fetch :warn_on_failure, true)
    end
    data
  end

  # Public: Read the contents of the file at the specified path.
  # This method assumes that the path is safe to read. It checks
  # that the file is readable before attempting to read it.
  #
  # path - the String path from which to read the contents
  # opts - a Hash of options to control processing (default: {})
  #        * :warn_on_failure a Boolean that controls whether a warning
  #          is issued if the file cannot be read (default: false)
  #        * :normalize a Boolean that controls whether the lines
  #          are normalized and coerced to UTF-8 (default: false)
  #
  # Returns the [String] content of the file at the specified path, or nil
  # if the file does not exist.
  def read_asset(path, opts = {})
    # remap opts for backwards compatibility
    opts = { :warn_on_failure => (opts != false) } unless ::Hash === opts
    if ::File.readable? path
      if opts[:normalize]
        Helpers.normalize_lines_from_string(::IO.read(path)) * EOL
      else
        # QUESTION should we chomp or rstrip content?
        ::IO.read(path)
      end
    else
      warn %(asciidoctor: WARNING: file does not exist or cannot be read: #{path}) if opts[:warn_on_failure]
      nil
    end
  end

  # Public: Normalize the web page using the PathResolver.
  #
  # See {PathResolver#web_path} for details.
  #
  # target              - the String target path
  # start               - the String start (i.e, parent) path (optional, default: nil)
  # preserve_uri_target - a Boolean indicating whether target should be preserved if contains a URI (default: true)
  #
  # Returns the resolved [String] path
  def normalize_web_path(target, start = nil, preserve_uri_target = true)
    if preserve_uri_target && (Helpers.uriish? target)
      target
    else
      (@path_resolver ||= PathResolver.new).web_path target, start
    end
  end

  # Public: Resolve and normalize a secure path from the target and start paths
  # using the PathResolver.
  #
  # See {PathResolver#system_path} for details.
  #
  # The most important functionality in this method is to prevent resolving a
  # path outside of the jail (which defaults to the directory of the source
  # file, stored in the base_dir instance variable on Document) if the document
  # safe level is set to SafeMode::SAFE or greater (a condition which is true
  # by default).
  #
  # target - the String target path
  # start  - the String start (i.e., parent) path
  # jail   - the String jail path to confine the resolved path
  # opts   - an optional Hash of options to control processing (default: {}):
  #          * :recover is used to control whether the processor should auto-recover
  #              when an illegal path is encountered
  #          * :target_name is used in messages to refer to the path being resolved
  #
  # raises a SecurityError if a jail is specified and the resolved path is
  # outside the jail.
  #
  # Returns the [String] path resolved from the start and target paths, with any
  # parent references resolved and self references removed. If a jail is provided,
  # this path will be guaranteed to be contained within the jail.
  def normalize_system_path target, start = nil, jail = nil, opts = {}
    path_resolver = (@path_resolver ||= PathResolver.new)
    if (doc = @document).safe < SafeMode::SAFE
      if start
        start = ::File.join doc.base_dir, start unless path_resolver.is_root? start
      else
        start = doc.base_dir
      end
    else
      start = doc.base_dir unless start
      jail = doc.base_dir unless jail
    end
    path_resolver.system_path target, start, jail, opts
  end

  # Public: Normalize the asset file or directory to a concrete and rinsed path
  #
  # Delegates to normalize_system_path, with the start path set to the value of
  # the base_dir instance variable on the Document object.
  def normalize_asset_path(asset_ref, asset_name = 'path', autocorrect = true)
    normalize_system_path(asset_ref, @document.base_dir, nil,
        :target_name => asset_name, :recover => autocorrect)
  end

  # Public: Calculate the relative path to this absolute filename from the Document#base_dir
  def relative_path(filename)
    (@path_resolver ||= PathResolver.new).relative_path filename, @document.base_dir
  end

  # Public: Check whether the specified String is a URI by
  # matching it against the Asciidoctor::UriSniffRx regex.
  #
  # @deprecated Use Helpers.uriish? instead
  def is_uri? str
    Helpers.uriish? str
  end

  # Public: Retrieve the list marker keyword for the specified list type.
  #
  # For use in the HTML type attribute.
  #
  # list_type - the type of list; default to the @style if not specified
  #
  # Returns the single-character [String] keyword that represents the marker for the specified list type
  def list_marker_keyword(list_type = nil)
    ORDERED_LIST_KEYWORDS[list_type || @style]
  end
end
end
