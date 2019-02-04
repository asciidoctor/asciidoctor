require_relative 'docbook5'

module Asciidoctor
  # A built-in {Converter} implementation that generates DocBook 4.5 output
  # consistent with the docbook45 backend from AsciiDoc Python.
  class Converter::DocBook45Converter < Converter::DocBook5Converter
    register_for 'docbook45'

    def admonition node
      # address a bug in the DocBook 4.5 DTD
      if node.parent.context == :example
        %(<para>
#{super}
</para>)
      else
        super
      end
    end

    def olist node
      result = []
      num_attribute = node.style ? %( numeration="#{node.style}") : ''
      start_attribute = (node.attr? 'start') ? %( override="#{node.attr 'start'}") : ''
      result << %(<orderedlist#{_common_attributes node.id, node.role, node.reftext}#{num_attribute}>)
      result << %(<title>#{node.title}</title>) if node.title?
      node.items.each_with_index do |item, idx|
        result << (idx == 0 ? %(<listitem#{start_attribute}>) : '<listitem>')
        result << %(<simpara>#{item.text}</simpara>)
        result << item.content if item.blocks?
        result << '</listitem>'
      end
      result << %(</orderedlist>)
      result.join LF
    end

    def inline_anchor node
      case node.type
      when :ref
        %(<anchor#{_common_attributes node.target, nil, node.text}/>)
      when :xref
        if (path = node.attributes['path'])
          # QUESTION should we use refid as fallback text instead? (like the html5 backend?)
          %(<ulink url="#{node.target}">#{node.text || path}</ulink>)
        else
          linkend = node.attributes['fragment'] || node.target
          (text = node.text) ? %(<link linkend="#{linkend}">#{text}</link>) : %(<xref linkend="#{linkend}"/>)
        end
      when :link
        %(<ulink url="#{node.target}">#{node.text}</ulink>)
      when :bibref
        target = node.target
        %(<anchor#{_common_attributes target, nil, "[#{target}]"}/>[#{target}])
      end
    end

    private

    def _author_tag author
      result = []
      result << '<author>'
      result << %(<firstname>#{author.firstname}</firstname>) if author.firstname
      result << %(<othername>#{author.middlename}</othername>) if author.middlename
      result << %(<surname>#{author.lastname}</surname>) if author.lastname
      result << %(<email>#{author.email}</email>) if author.email
      result << '</author>'
      result.join LF
    end

    def _common_attributes id, role = nil, reftext = nil
      res = id ? %( id="#{id}") : ''
      res = %(#{res} role="#{role}") if role
      res = %(#{res} xreflabel="#{reftext}") if reftext
      res
    end

    def _doctype_declaration root_tag_name
      %(<!DOCTYPE #{root_tag_name} PUBLIC "-//OASIS//DTD DocBook XML V4.5//EN" "http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd">)
    end

    def _document_info_tag doc, info_tag_prefix
      super doc, info_tag_prefix, true
    end

    def _lang_attribute_name
      'lang'
    end

    def _document_ns_attributes doc
      (ns = doc.attr 'xmlns') ? (ns.empty? ? ' xmlns="http://docbook.org/ns/docbook"' : %( xmlns="#{ns}")) : ''
    end
  end
end
