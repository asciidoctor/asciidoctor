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
  # name    - the name of the attribute to lookup as a String or Symbol
  # default - the value to return if the attribute is not found (default: nil)
  #
  # return the value of the attribute or the default value if the attribute
  # is not found in the attributes of this node or the document node
  def attr(name, default = nil)
    name = name.to_s if name.is_a?(Symbol)
    if self == @document
      default.nil? ? @attributes[name] : @attributes.fetch(name, default)
    else
      default.nil? ? @attributes.fetch(name, @document.attr(name)) :
          @attributes.fetch(name, @document.attr(name, default))
    end
  end

  # Public: Check if the attribute is defined, optionally performing a
  # comparison of its value
  #
  # Check if the attribute is defined. First look in the attributes on this
  # node. If not found, and this node is a child of the Document node, look in
  # the attributes of the Document node. If the attribute is found and a
  # comparison value is specified, return whether the two values match.
  # Otherwise, return whether the attribute was found.
  #
  # name   - the name of the attribute to lookup as a String or Symbol
  # expect - the expected value of the attribute (default: nil)
  #
  # return a Boolean indicating whether the attribute exists and, if a
  # comparison value is specified, whether the value of the attribute matches
  # the comparison value
  def attr?(name, expect = nil)
    name = name.to_s if name.is_a?(Symbol)
    if expect.nil?
      if @attributes.has_key? name
        true
      elsif self != @document
        @document.attributes.has_key? name
      else
        false
      end
    else
      if @attributes.has_key? name
        @attributes[name] == expect
      elsif self != @document && @document.attributes.has_key?(name)
        @document.attributes[name] == expect
      else
        false
      end
    end
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
      image_uri(name + '.' + @document.attr('icontype', 'png'), 'iconsdir')
    end
  end

  # Public: Construct a reference or data URI to the target image.
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
      File.join(@document.attr(asset_dir_key), target_image)
    else
      target_image
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

    mimetype = 'image/' + File.extname(target_image)[1..-1]
    if asset_dir_key
      image_path = File.join(normalize_asset_path(@document.attr(asset_dir_key, '.'), asset_dir_key), target_image)
    else
      image_path = normalize_asset_path(target_image)
    end

    bindata = nil
    if IO.respond_to? :binread
      bindata = IO.binread(image_path)
    else
      bindata = File.open(image_path, 'rb') {|file| file.read }
    end
    'data:' + mimetype + ';base64,' + Base64.encode64(bindata).delete("\n")
  end

  # Public: Normalize the asset file or directory to a concrete and rinsed path
  #
  # The most important functionality in this method is to prevent the asset
  # reference from resolving to a directory outside of the chroot directory
  # (which defaults to the directory of the source file, stored in the base_dir
  # instance variable on Document) if the document safe level is set to
  # SafeMode::SAFE or greater (a condition which is true by default).
  #
  # asset_ref    - the String asset file or directory referenced in the document
  #                or configuration attribute
  # asset_name   - the String name of the file or directory being resolved (for use in
  #                the warning message) (default: 'path')
  #
  # Examples
  #
  #  # given these fixtures
  #  document.base_dir
  #  # => "/path/to/chroot"
  #  document.safe >= Asciidoctor::SafeMode::SAFE
  #  # => true
  #
  #  # then
  #  normalize_asset_path('images')
  #  # => "/path/to/chroot/images"
  #  normalize_asset_path('/etc/images')
  #  # => "/path/to/chroot/images"
  #  normalize_asset_path('../images')
  #  # => "/path/to/chroot/images"
  #
  #  # given these fixtures
  #  document.base_dir
  #  # => "/path/to/chroot"
  #  document.safe >= Asciidoctor::SafeMode::SAFE
  #  # => false
  #
  #  # then
  #  normalize_asset_path('images')
  #  # => "/path/to/chroot/images"
  #  normalize_asset_path('/etc/images')
  #  # => "/etc/images"
  #  normalize_asset_path('../images')
  #  # => "/path/to/images"
  #
  # Returns The normalized asset file or directory as a String path
  #--
  # TODO this method is missing a coordinate; it should be able to resolve
  # both the directory reference and the path to an asset in it; callers
  # of this method are still doing a File.join to finish the task
  def normalize_asset_path(asset_ref, asset_name = 'path', autocorrect = true)
    # TODO we may use pathname enough to make it a top-level require
    Helpers.require_library 'pathname'

    input_path = @document.base_dir
    asset_path = Pathname.new(asset_ref)
    
    if asset_path.relative?
      asset_path = File.expand_path(File.join(input_path, asset_ref))
    else
      asset_path = asset_path.cleanpath.to_s
    end

    if @document.safe >= SafeMode::SAFE
      relative_asset_path = Pathname.new(asset_path).relative_path_from(Pathname.new(input_path)).to_s
      if relative_asset_path.start_with?('..')
        if autocorrect
          puts "asciidoctor: WARNING: #{asset_name} has illegal reference to ancestor of base directory"
        else
          raise SecurityError, "#{asset_name} has reference to path outside of base directory, disallowed in safe mode: #{asset_path}"
        end
        relative_asset_path.sub!(/^(?:\.\.\/)*/, '')
        # just to be absolutely sure ;)
        if relative_asset_path[0..0] == '.'
          raise 'Substitution of parent path references failed for ' + relative_asset_path
        end
        asset_path = File.expand_path(File.join(input_path, relative_asset_path))
      end
    end

    asset_path
  end

end
end
