module Asciidoctor
# Public: An abstract base class that provides state and methods for managing a
# node of AsciiDoc content. The state and methods on this class are comment to
# all content segments in an AsciiDoc document.
class AbstractNode

  include Substituters

  # Public: Get the element which is the parent of this node
  attr_reader :parent

  # Public: Get the Asciidoctor::Document to which this node belongs
  attr_reader :document

  # Public: Get the Symbol context for this node
  attr_reader :context

  # Public: Get the id of this node
  attr_accessor :id

  # Public: Get the Hash of attributes for this node
  attr_reader :attributes

  def initialize(parent, context)
    @parent = (context != :document ? parent : nil)

    if !parent.nil?
      @document = parent.is_a?(Document) ? parent : parent.document
    else
      @document = nil
    end
    
    @context = context
    @attributes = {}
    @passthroughs = []
  end

  # Public: Get the value of the specified attribute
  #
  # Get the value for the specified attribute. First look in the attributes on
  # this node and return the value of the attribute if found. Otherwise, if
  # this node is a child of the Document node, look in the attributes of the
  # Document node and return the value of the attribute if found. Otherwise,
  # return the default value, which defaults to nil.
  #
  # name    - the String or Symbol name of the attribute to lookup
  # default - the Object value to return if the attribute is not found (default: nil)
  # inherit - a Boolean indicating whether to check for the attribute on the
  #           AsciiDoctor::Document if not found on this node (default: false)
  #
  # return the value of the attribute or the default value if the attribute
  # is not found in the attributes of this node or the document node
  def attr(name, default = nil, inherit = true)
    name = name.to_s if name.is_a?(Symbol)
    inherit = false if self == @document
    if !inherit
      default.nil? ? @attributes[name] : @attributes.fetch(name, default)
    else
      default.nil? ? @attributes.fetch(name, @document.attr(name)) :
          @attributes.fetch(name, @document.attr(name, default))
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
    name = name.to_s if name.is_a?(Symbol)
    inherit = false if self == @document
    if expect.nil?
      if @attributes.has_key? name
        true
      elsif inherit
        @document.attributes.has_key? name
      else
        false
      end
    else
      if @attributes.has_key? name
        @attributes[name] == expect
      elsif inherit && @document.attributes.has_key?(name)
        @document.attributes[name] == expect
      else
        false
      end
    end
  end

  # Public: Assign the value to the specified key in this
  # block's attributes hash.
  #
  # key - The attribute key (or name)
  # val - The value to assign to the key
  #
  # returns a flag indicating whether the assignment was performed
  def set_attr(key, val, overwrite = nil)
    if overwrite.nil?
      @attributes[key] = val
      true
    else
      if overwrite || @attributes.has_key?(key)
        @attributes[key] = val
        true
      else
        false
      end
    end
  end

  # Public: A convenience method to check if the specified option attribute is
  # enabled on the current node.
  #
  # Check if the option is enabled. This method simply checks to see if the
  # {name}-option attribute is defined on the current node.
  #
  # name    - the String or Symbol name of the option
  #
  # return a Boolean indicating whether the option has been specified
  def option?(name)
    @attributes.has_key? "#{name}-option"
  end

  # Public: Get the execution context of this object (via Kernel#binding).
  #
  # This method is used to set the 'self' reference as well as local variables
  # that map to this method's arguments during the evaluation of a backend
  # template.
  #
  # Each object in Ruby has a binding context that can be used to set the 'self'
  # reference in an evaluation context. Any arguments passed to this
  # method are also available in the execution environment.
  #
  # template -  The BaseTemplate instance in which this binding will be active.
  #             Bound to the local variable of the same name, template.
  #
  # returns the execution context for this object so it can be be transferred to
  # the backend template and binds the method arguments as local variables in
  # that same environment.
  def get_binding template
    binding
  end

  # Public: Update the attributes of this node with the new values in
  # the attributes argument.
  #
  # If an attribute already exists with the same key, it's value will
  # be overridden.
  #
  # attributes - A Hash of attributes to assign to this node.
  #
  # returns nothing
  def update_attributes(attributes)
    @attributes.update(attributes)
    nil
  end

  # Public: Get the Asciidoctor::Renderer instance being used for the
  # Asciidoctor::Document to which this node belongs
  def renderer
    @document.renderer
  end

  # Public: A convenience method that checks if the role attribute is specified
  def role?(expect = nil)
    self.attr?('role', expect)
  end

  # Public: A convenience method that returns the value of the role attribute
  def role
    self.attr('role')
  end

  # Public: A convenience method that checks if the specified role is present
  # in the list of roles on this node
  def has_role?(name)
    roles.include?(name)
  end

  # Public: A convenience method that returns the role names as an Array
  def roles
    self.attr('role').to_s.split(' ')
  end

  # Public: A convenience method that checks if the reftext attribute is specified
  def reftext?
    self.attr?('reftext')
  end

  # Public: A convenience method that returns the value of the reftext attribute
  def reftext
    self.attr('reftext')
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
  def icon_uri(name)
    if attr? 'icon'
      image_uri(attr('icon'), nil)
    else
      image_uri("#{name}.#{@document.attr('icontype', 'png')}", 'iconsdir')
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
    if target.include?(':') && target.match(Asciidoctor::REGEXP[:uri_sniff])
      target
    elsif asset_dir_key && attr?(asset_dir_key)
      normalize_web_path(target, @document.attr(asset_dir_key))
    else
      normalize_web_path(target)
    end
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
    if target_image.include?(':') && target_image.match(Asciidoctor::REGEXP[:uri_sniff])
      target_image
    elsif @document.safe < Asciidoctor::SafeMode::SECURE && @document.attr?('data-uri')
      generate_data_uri(target_image, asset_dir_key)
    elsif asset_dir_key && attr?(asset_dir_key)
      normalize_web_path(target_image, @document.attr(asset_dir_key))
    else
      normalize_web_path(target_image)
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
    Helpers.require_library 'base64'

    ext = File.extname(target_image)[1..-1]
    mimetype = 'image/' + ext
    mimetype = "#{mimetype}+xml" if ext == 'svg'
    if asset_dir_key
      #asset_dir_path = normalize_system_path(@document.attr(asset_dir_key), nil, nil, :target_name => asset_dir_key)
      #image_path = normalize_system_path(target_image, asset_dir_path, nil, :target_name => 'image')
      image_path = normalize_system_path(target_image, @document.attr(asset_dir_key), nil, :target_name => 'image')
    else
      image_path = normalize_system_path(target_image)
    end

    if !File.readable? image_path
      puts "asciidoctor: WARNING: image to embed not found or not readable: #{image_path}"
      return "data:#{mimetype}:base64,"
      #return 'data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw=='
    end

    bindata = nil
    if IO.respond_to? :binread
      bindata = IO.binread(image_path)
    else
      bindata = File.open(image_path, 'rb') {|file| file.read }
    end
    "data:#{mimetype};base64,#{Base64.encode64(bindata).delete("\n")}"
  end

  # Public: Read the contents of the file at the specified path.
  # This method assumes that the path is safe to read. It checks
  # that the file is readable before attempting to read it.
  #
  # path            - the String path from which to read the contents
  # warn_on_failure - a Boolean that controls whether a warning is issued if
  #                   the file cannot be read
  #
  # returns the contents of the file at the specified path, or nil
  # if the file does not exist.
  def read_asset(path, warn_on_failure = false)
    if File.readable? path
      File.read(path).chomp
    else
      puts "asciidoctor: WARNING: file does not exist or cannot be read: #{path}" if warn_on_failure
      nil
    end
  end

  # Public: Normalize the web page using the PathResolver.
  #
  # See PathResolver::web_path(target, start) for details.
  #
  # target - the String target path
  # start  - the String start (i.e, parent) path (optional, default: nil)
  #
  # returns the resolved String path 
  def normalize_web_path(target, start = nil)
    PathResolver.new.web_path(target, start)
  end

  # Public: Resolve and normalize a secure path from the target and start paths
  # using the PathResolver.
  #
  # See PathResolver::system_path(target, start, jail, opts) for details.
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
  # returns a String path resolved from the start and target paths, with any
  # parent references resolved and self references removed. If a jail is provided,
  # this path will be guaranteed to be contained within the jail.
  def normalize_system_path(target, start = nil, jail = nil, opts = {})
    if start.nil?
      start = @document.base_dir
    end
    if jail.nil? && @document.safe >= SafeMode::SAFE
      jail = @document.base_dir
    end
    PathResolver.new.system_path(target, start, jail, opts)
  end

  # Public: Normalize the asset file or directory to a concrete and rinsed path
  #
  # Delegates to normalize_system_path, with the start path set to the value of
  # the base_dir instance variable on the Document object.
  def normalize_asset_path(asset_ref, asset_name = 'path', autocorrect = true)
    normalize_system_path(asset_ref, @document.base_dir, nil,
        :target_name => asset_name, :recover => autocorrect)
  end

  # Public: Retrieve the list marker keyword for the specified list type.
  #
  # For use in the HTML type attribute.
  #
  # list_type - the type of list; default to the @style if not specified
  #
  # returns the single-character String keyword that represents the marker for the specified list type
  def list_marker_keyword(list_type = nil)
    ORDERED_LIST_KEYWORDS[list_type || @style]
  end

end
end
