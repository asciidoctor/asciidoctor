# encoding: UTF-8
module Asciidoctor
# Public: An abstract base class that provides state and methods for managing a
# node of AsciiDoc content. The state and methods on this class are comment to
# all content segments in an AsciiDoc document.
class AbstractNode
  include Logging
  include Substitutors

  # Public: Get the Hash of attributes for this node
  attr_reader :attributes

  # Public: Get the Symbol context for this node
  attr_reader :context

  # Public: Get the Asciidoctor::Document to which this node belongs
  attr_reader :document

  # Public: Get/Set the id of this node
  attr_accessor :id

  # Public: Get the String name of this node
  attr_reader :node_name

  # Public: Get the element which is the parent of this node
  attr_reader :parent

  def initialize parent, context, opts = {}
    if context == :document
      # document is a special case, should refer to itself
      @document, @parent = self, nil
    else
      if parent
        @document, @parent = parent.document, parent
      else
        @document = @parent = nil
      end
    end
    @node_name = (@context = context).to_s
    # QUESTION are we correct in duplicating the attributes (seems to be just as fast)
    @attributes = (opts.key? :attributes) ? opts[:attributes].dup : {}
    @passthroughs = {}
  end

  # Public: Returns whether this {AbstractNode} is an instance of {Block}
  #
  # Returns [Boolean]
  def block?
    # :nocov:
    raise ::NotImplementedError
    # :nocov:
  end

  # Public: Returns whether this {AbstractNode} is an instance of {Inline}
  #
  # Returns [Boolean]
  def inline?
    # :nocov:
    raise ::NotImplementedError
    # :nocov:
  end

  # Public: Get the Asciidoctor::Converter instance being used to convert the
  # current Asciidoctor::Document.
  def converter
    @document.converter
  end

  # Public: Associate this Block with a new parent Block
  #
  # parent - The Block to set as the parent of this Block
  #
  # Returns the new parent Block associated with this Block
  def parent= parent
    @parent, @document = parent, parent.document
  end

  # Public: Get the value of the specified attribute
  #
  # Get the value for the specified attribute. First look in the attributes on
  # this node and return the value of the attribute if found. Otherwise, if
  # this node is a child of the Document node, look in the attributes of the
  # Document node and return the value of the attribute if found. Otherwise,
  # return the default value, which defaults to nil.
  #
  # name        - the String or Symbol name of the attribute to lookup
  # default_val - the Object value to return if the attribute is not found (default: nil)
  # inherit     - a Boolean indicating whether to check for the attribute on the
  #               AsciiDoctor::Document if not found on this node (default: false)
  #
  # return the value of the attribute or the default value if the attribute
  # is not found in the attributes of this node or the document node
  def attr name, default_val = nil, inherit = true
    name = name.to_s
    # NOTE if @parent is set, it means @document is also set
    @attributes[name] || (inherit && @parent ? @document.attributes[name] || default_val : default_val)
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
  # name       - the String or Symbol name of the attribute to lookup
  # expect_val - the expected Object value of the attribute (default: nil)
  # inherit    - a Boolean indicating whether to check for the attribute on the
  #              AsciiDoctor::Document if not found on this node (default: false)
  #
  # return a Boolean indicating whether the attribute exists and, if a
  # comparison value is specified, whether the value of the attribute matches
  # the comparison value
  def attr? name, expect_val = nil, inherit = true
    name = name.to_s
    # NOTE if @parent is set, it means @document is also set
    if expect_val.nil?
      (@attributes.key? name) || (inherit && @parent && (@document.attributes.key? name))
    else
      expect_val == (@attributes[name] || (inherit && @parent ? @document.attributes[name] : nil))
    end
  end

  # Public: Assign the value to the attribute name for the current node.
  #
  # name      - The String attribute name to assign
  # value     - The Object value to assign to the attribute (default: '')
  # overwrite - A Boolean indicating whether to assign the attribute
  #             if currently present in the attributes Hash (default: true)
  #
  # Returns a [Boolean] indicating whether the assignment was performed
  def set_attr name, value = '', overwrite = true
    if overwrite == false && (@attributes.key? name)
      false
    else
      @attributes[name] = value
      true
    end
  end

  # Public: Remove the attribute from the current node.
  #
  # name      - The String attribute name to remove
  #
  # Returns the previous [String] value, or nil if the attribute was not present.
  def remove_attr name
    @attributes.delete name
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
    @attributes.key? %(#{name}-option)
  end

  # Public: Set the specified option on this node.
  #
  # This method sets the specified option on this node if not already set.
  # It will add the name to the options attribute and set the <name>-option
  # attribute.
  #
  # name - the String name of the option
  #
  # returns truthy if the option was set or falsey if the option was already set
  def set_option(name)
    if (attrs = @attributes)['options']
      unless attrs[key = %(#{name}-option)]
        attrs['options'] += %(,#{name})
        attrs[key] = ''
      end
    else
      attrs['options'] = name
      attrs[%(#{name}-option)] = ''
    end
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

  # Public: A convenience method that returns the value of the role attribute
  def role
    @attributes['role'] || @document.attributes['role']
  end

  # Public: A convenience method that returns the role names as an Array
  #
  # Returns the role names as an Array or an empty Array if the role attribute is absent.
  def roles
    (val = @attributes['role'] || @document.attributes['role']).nil_or_empty? ? [] : val.split
  end

  # Public: A convenience method that checks if the role attribute is specified
  def role? expect_val = nil
    if expect_val
      expect_val == (@attributes['role'] || @document.attributes['role'])
    else
      @attributes.key?('role') || @document.attributes.key?('role')
    end
  end

  # Public: A convenience method that checks if the specified role is present
  # in the list of roles on this node
  def has_role?(name)
    # NOTE center + include? is faster than split + include?
    (val = @attributes['role'] || @document.attributes['role']) ? %( #{val} ).include?(%( #{name} )) : false
  end

  # Public: A convenience method that adds the given role directly to this node
  #
  # Returns a Boolean indicating whether the role was added.
  def add_role(name)
    if (val = @attributes['role']).nil_or_empty?
      @attributes['role'] = name
      true
    # NOTE center + include? is faster than split + include?
    elsif %( #{val} ).include?(%( #{name} ))
      false
    else
      @attributes['role'] = %(#{val} #{name})
      true
    end
  end

  # Public: A convenience method that removes the given role directly from this node
  #
  # Returns a Boolean indicating whether the role was removed.
  def remove_role(name)
    if (val = @attributes['role']).nil_or_empty?
      false
    elsif (val = val.split).delete name
      if val.empty?
        @attributes.delete('role')
      else
        @attributes['role'] = val.join ' '
      end
      true
    else
      false
    end
  end

  # Public: A convenience method that returns the value of the reftext attribute with substitutions applied.
  def reftext
    (val = @attributes['reftext']) ? (apply_reftext_subs val) : nil
  end

  # Public: A convenience method that checks if the reftext attribute is defined.
  def reftext?
    @attributes.key? 'reftext'
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
      if ::File.extname(icon = (attr 'icon')).empty?
        # QUESTION should we be adding the extension if the icon is an absolute URI?
        icon = %(#{icon}.#{@document.attr 'icontype', 'png'})
      end
    else
      icon = %(#{name}.#{@document.attr 'icontype', 'png'})
    end
    image_uri icon, 'iconsdir'
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
    if (doc = @document).safe < SafeMode::SECURE && (doc.attr? 'data-uri')
      if ((Helpers.uriish? target_image) && (target_image = uri_encode_spaces target_image)) ||
          (asset_dir_key && (images_base = doc.attr asset_dir_key) && (Helpers.uriish? images_base) &&
          (target_image = normalize_web_path target_image, images_base, false))
        if doc.attr? 'allow-uri-read'
          generate_data_uri_from_uri target_image, (doc.attr? 'cache-uri')
        else
          target_image
        end
      else
        generate_data_uri target_image, asset_dir_key
      end
    else
      normalize_web_path target_image, (asset_dir_key ? (doc.attr asset_dir_key) : nil)
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

    if ::File.readable? image_path
      # NOTE base64 is autoloaded by reference to ::Base64
      %(data:#{mimetype};base64,#{::Base64.strict_encode64 ::IO.binread image_path})
    else
      logger.warn %(image to embed not found or not readable: #{image_path})
      %(data:#{mimetype};base64,)
      # uncomment to return 1 pixel white dot instead
      #'data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw=='
    end
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
      bindata = open image_uri, 'rb' do |f|
        mimetype = f.content_type
        f.read
      end
      # NOTE base64 is autoloaded by reference to ::Base64
      %(data:#{mimetype};base64,#{::Base64.strict_encode64 bindata})
    rescue
      logger.warn %(could not retrieve image data from URI: #{image_uri})
      image_uri
      # uncomment to return empty data (however, mimetype needs to be resolved)
      #%(data:#{mimetype}:base64,)
      # uncomment to return 1 pixel white dot instead
      #'data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw=='
    end
  end

  # Public: Normalize the asset file or directory to a concrete and rinsed path
  #
  # Delegates to normalize_system_path, with the start path set to the value of
  # the base_dir instance variable on the Document object.
  def normalize_asset_path(asset_ref, asset_name = 'path', autocorrect = true)
    normalize_system_path(asset_ref, @document.base_dir, nil,
        :target_name => asset_name, :recover => autocorrect)
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
  #          * :recover is used to control whether the processor should
  #            automatically recover when an illegal path is encountered
  #          * :target_name is used in messages to refer to the path being resolved
  #
  # raises a SecurityError if a jail is specified and the resolved path is
  # outside the jail.
  #
  # Returns the [String] path resolved from the start and target paths, with any
  # parent references resolved and self references removed. If a jail is provided,
  # this path will be guaranteed to be contained within the jail.
  def normalize_system_path target, start = nil, jail = nil, opts = {}
    if (doc = @document).safe < SafeMode::SAFE
      if start
        start = ::File.join doc.base_dir, start unless doc.path_resolver.root? start
      else
        start = doc.base_dir
      end
    else
      start = doc.base_dir unless start
      jail = doc.base_dir unless jail
    end
    doc.path_resolver.system_path target, start, jail, opts
  end

  # Public: Normalize the web path using the PathResolver.
  #
  # See {PathResolver#web_path} for details about path resolution and encoding.
  #
  # target              - the String target path
  # start               - the String start (i.e, parent) path (optional, default: nil)
  # preserve_uri_target - a Boolean indicating whether target should be preserved if contains a URI (default: true)
  #
  # Returns the resolved [String] path
  def normalize_web_path(target, start = nil, preserve_uri_target = true)
    if preserve_uri_target && (Helpers.uriish? target)
      uri_encode_spaces target
    else
      @document.path_resolver.web_path target, start
    end
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
  def read_asset path, opts = {}
    # remap opts for backwards compatibility
    opts = { :warn_on_failure => (opts != false) } unless ::Hash === opts
    if ::File.readable? path
      if opts[:normalize]
        # NOTE Opal does not yet support File#readlines
        (Helpers.normalize_lines_array ::File.open(path, 'rb') {|f| f.each_line.to_a }).join LF
      else
        # QUESTION should we chomp or rstrip content?
        ::IO.read path
      end
    elsif opts[:warn_on_failure]
      logger.warn %(#{(attr 'docfile') || '<stdin>'}: #{opts[:label] || 'file'} does not exist or cannot be read: #{path})
      nil
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
        (target = doc.path_resolver.web_path target, start))
      if doc.attr? 'allow-uri-read'
        Helpers.require_library 'open-uri/cached', 'open-uri-cached' if doc.attr? 'cache-uri'
        begin
          if opts[:normalize]
            # NOTE Opal does not yet support File#readlines
            (Helpers.normalize_lines_array ::OpenURI.open_uri(target) {|f| f.each_line.to_a }).join LF
          else
            ::OpenURI.open_uri(target) {|f| f.read }
          end
        rescue
          logger.warn %(could not retrieve contents of #{opts[:label] || 'asset'} at URI: #{target}) if opts.fetch :warn_on_failure, true
          return
        end
      else
        logger.warn %(cannot retrieve contents of #{opts[:label] || 'asset'} at URI: #{target} (allow-uri-read attribute not enabled)) if opts.fetch :warn_on_failure, true
        return
      end
    else
      target = normalize_system_path target, opts[:start], nil, :target_name => (opts[:label] || 'asset')
      read_asset target, :normalize => opts[:normalize], :warn_on_failure => (opts.fetch :warn_on_failure, true), :label => opts[:label]
    end
  end

  # Internal: URI encode spaces in a String
  #
  # str - the String to encode
  #
  # Returns the String with all spaces replaced with %20.
  def uri_encode_spaces str
    (str.include? ' ') ? (str.gsub ' ', '%20') : str
  end

  # Public: Check whether the specified String is a URI by
  # matching it against the Asciidoctor::UriSniffRx regex.
  #
  # @deprecated Use Helpers.uriish? instead
  def is_uri? str
    Helpers.uriish? str
  end
end
end
