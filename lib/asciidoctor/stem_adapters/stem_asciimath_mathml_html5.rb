module Asciidoctor

  class StemAdapter::TransformAsciimathMathmlHtml5
    include Asciidoctor::StemAdapter::PluginBase
    register_for :asciimath, :mathml, :html5

    public

    def common_attributes id, role = nil, reftext = nil
      if id
        attrs = %( xml:id="#{id}"#{role ? %( role="#{role}") : ''})
      elsif role
        attrs = %( role="#{role}")
      else
        attrs = ''
      end
      if reftext
        if (reftext.include? '<') && ((reftext = reftext.gsub XmlSanitizeRx, '').include? ' ')
          reftext = (reftext.squeeze ' ').strip
        end
        reftext = reftext.gsub '"', '&quot;' if reftext.include? '"'
        %(#{attrs} xreflabel="#{reftext}")
      else
        attrs
      end
    end

    def docinfo? location
      false
    end
    def convert node
      if (idx = node.subs.index :specialcharacters)
        node.subs.delete_at idx
        equation = node.content
        idx > 0 ? (node.subs.insert idx, :specialcharacters) : (node.subs.unshift :specialcharacters)
      else
        equation = node.content
      end
      if node.style == 'asciimath'
        # NOTE fop requires jeuclid to process mathml markup
        equation_data = asciimath_available? ? ((::AsciiMath.parse equation).to_mathml '', 'xmlns:mml' => 'http://www.w3.org/1998/Math/MathML') : %(<mathphrase><![CDATA[#{equation}]]></mathphrase>)
      else
        # unhandled math; pass source to alt and required mathphrase element; dblatex will process alt as LaTeX math
        equation_data = %(<alt><![CDATA[#{equation}]]></alt>
<mathphrase><![CDATA[#{equation}]]></mathphrase>)
      end
      if node.title?
        %(<equation#{common_attributes node.id, node.role, node.reftext}>
<title>#{node.title}</title>
#{equation_data}
</equation>)
      else
        # WARNING dblatex displays the <informalequation> element inline instead of block as documented (except w/ mathml)
        %(<informalequation#{common_attributes node.id, node.role, node.reftext}>
#{equation_data}
</informalequation>)
      end
    end

    def asciimath_available?
      (@asciimath_status ||= load_asciimath) == :loaded
    end

    def load_asciimath
      (defined? ::AsciiMath.parse) ? :loaded : (Helpers.require_library 'asciimath', true, :warn).nil? ? :unavailable : :loaded
    end

  end
end
