class Asciidoctor::AbstractNode
  include Asciidoctor::Substituters

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
      @document = parent.is_a?(Asciidoctor::Document) ? parent : parent.document
    else
      @document = nil
    end
    @context = context
    @attributes = {}
    @passthroughs = []
  end

  def attr(name, default = nil)
    if self == @document
      default.nil? ? @attributes[name.to_s] : @attributes.fetch(name.to_s, default)
    else
      default.nil? ? @attributes.fetch(name.to_s, @document.attr(name)) :
          @attributes.fetch(name.to_s, @document.attr(name, default))
    end
  end

  def attr?(name)
    if self == @document
      @attributes.has_key? name.to_s
    else
      @attributes.has_key?(name.to_s) || @document.attr?(name)
    end
  end

  def update_attributes(attributes)
    @attributes.update(attributes)
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
  # attribute, the icon name and the value of the 'iconstype' attribute
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
      image_uri(name + '.' + document.attr('iconstype', 'png'), 'iconsdir')
    end
  end

  # Public: Construct a reference or data URI to the target image.
  #
  # The target image is resolved relative to the directory retrieved from the
  # specified attribute key, if provided.
  #
  # If the 'data-uri' attribute is set on the document, the image will be
  # safely converted to a data URI by reading it from the same directory.
  #
  # The return value of this method can be safely used in an image tag.
  #
  # target_image - A String path to the target image
  # assetdir_key - The String attribute key used to lookup the directory where
  #                the image is located (default: 'imagesdir')
  #
  # Returns A String reference or data URI for the target image
  def image_uri(target_image, assetdir_key = 'imagesdir')
    if document.attr? 'data-uri'
      generate_data_uri(target_image, assetdir_key)
    elsif assetdir_key && attr?(assetdir_key)
      File.join(document.attr(assetdir_key), target_image)
    else
      target_image
    end
  end

  # Public: Generate a data URI that can be used to embed an image in the output document
  #
  # First, and foremost, the target image path is cleaned if the 'safepaths' attribute is
  # set (on by default) to prevent access to ancestor paths in the filesystem. The
  # image data is then read and converted to Base64. Finally, a data URI is built which
  # can be used in an image tag.
  #
  # target_image - A String path to the target image
  # assetdir_key - The String attribute key used to lookup the directory where
  #                the image is located (default: nil)
  #
  # Returns A String data URI containing the content of the target image
  def generate_data_uri(target_image, assetdir_key = nil)
    require 'base64'

    mimetype = 'image/' + File.extname(target_image)[1..-1]
    if assetdir_key
      image_path = File.join(normalize_assetpath(document.attr(assetdir_key, '.'), assetdir_key), target_image)
    else
      image_path = normalize_assetpath(target_image)
    end
    'data:' + mimetype + ';base64,' + Base64.encode64(IO.read(image_path)).delete("\n")
  end

  # Public: Normalize the specified asset directory to a concrete directory path
  #
  # The most important functionality in this method is to prevent the asset directory
  # from resolving to a directory outside of the chroot directory (which defaults to docdir)
  # if the 'safepaths' attribute is true (the default).
  #
  # assetdir     - The String asset directory as provided in the configuration
  # asset_name   - The String name of the property being resolved (for use in
  #                the warning message) (default: 'asset directory')
  #
  # Examples
  #
  #  # given these fixtures
  #  document.attr('docdir')
  #  # => "/path/to/docdir"
  #  document.attr('safepaths')
  #  # => true
  #
  #  # then
  #  normalize_assetpath('images')
  #  # => "/path/to/docdir/images"
  #  normalize_assetpath('/etc/images')
  #  # => "/path/to/docdir/images"
  #  normalize_assetpath('../images')
  #  # => "/path/to/docdir/images"
  #
  #  # given these fixtures
  #  document.attr('docdir')
  #  # => "/path/to/docdir"
  #  document.attr('safepaths')
  #  # => false
  #
  #  # then
  #  normalize_assetpath('images')
  #  # => "/path/to/docdir/images"
  #  normalize_assetpath('/etc/images')
  #  # => "/etc/images"
  #  normalize_assetpath('../images')
  #  # => "/path/to/images"
  #
  # Returns The normalized asset directory as a String
  def normalize_assetpath(assetdir, asset_name = 'asset directory')
    require 'pathname'
    inputpath = File.expand_path(document.attr('docdir'))
    assetpath = Pathname.new(assetdir)
    if assetpath.relative?
      assetpath = File.expand_path(File.join(inputpath, assetdir))
    else
      assetpath = assetpath.cleanpath.to_s
    end

    if document.attr('safepaths', true)
      relative_assetdir = Pathname.new(assetpath).relative_path_from(Pathname.new(inputpath)).to_s
      if relative_assetdir.start_with?('..')
        puts 'asciidoctor: WARNING: ' + asset_name + ' has illegal reference to ancestor of docdir'
        relative_assetdir.sub!(/^(?:\.\.\/)*/, '')
        # just to be absolutely sure ;)
        if relative_assetdir[0..0] == '.'
          raise 'Substitution of parent path references failed for ' + relative_assetdir
        end
        assetpath = File.expand_path(File.join(inputpath, relative_assetdir))
      end
    end
    assetpath
  end

end
