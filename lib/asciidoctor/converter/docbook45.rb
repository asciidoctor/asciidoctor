require 'asciidoctor/converter/docbook5'

module Asciidoctor
  # A built-in {Converter} implementation that generates DocBook 4.5 output
  # consistent with the docbook45 backend from AsciiDoc Python.
  class Converter::DocBook45Converter < Converter::DocBook5Converter
    def olist node
      result = []
      num_attribute = node.style ? %( numeration="#{node.style}") : nil
      start_attribute = (node.attr? 'start') ? %( override="#{node.attr 'start'}") : nil
      result << %(<orderedlist#{common_attributes node.id, node.role, node.reftext}#{num_attribute}>)
      result << %(<title>#{node.title}</title>) if node.title?
      node.items.each_with_index do |item, index|
        if index == 0
          result << %(<listitem#{start_attribute}>)
        else
          result << '<listitem>'
        end
        result << %(<simpara>#{item.text}</simpara>)
        result << item.content if item.blocks?
        result << '</listitem>'
      end
      result << %(</orderedlist>)
      result * EOL
    end

    def inline_anchor node
      target = node.target
      case node.type
      when :ref
        %(<anchor#{common_attributes target, nil, node.text}/>)
      when :xref
        if node.attr? 'path', nil
          linkend = (node.attr 'fragment') || target
          (text = node.text) ? %(<link linkend="#{linkend}">#{text}</link>) : %(<xref linkend="#{linkend}"/>)
        else
          text = node.text || (node.attr 'path')
          %(<ulink url="#{target}">#{text}</ulink>)
        end
      when :link
        %(<ulink url="#{target}">#{node.text}</ulink>)
      when :bibref
        %(<anchor#{common_attributes target, nil, "[#{target}]"}/>[#{target}])
      end
    end

    def author_element doc, index = nil
      firstname_key = index ? %(firstname_#{index}) : 'firstname'
      middlename_key = index ? %(middlename_#{index}) : 'middlename'
      lastname_key = index ? %(lastname_#{index}) : 'lastname'
      email_key = index ? %(email_#{index}) : 'email'

      result = []
      result << '<author>'
      result << %(<firstname>#{doc.attr firstname_key}</firstname>) if doc.attr? firstname_key
      result << %(<othername>#{doc.attr middlename_key}</othername>) if doc.attr? middlename_key
      result << %(<surname>#{doc.attr lastname_key}</surname>) if doc.attr? lastname_key
      result << %(<email>#{doc.attr email_key}</email>) if doc.attr? email_key
      result << '</author>'

      result * EOL
    end

    def common_attributes id, role = nil, reftext = nil
      res = id ? %( id="#{id}") : ''
      res = %(#{res} role="#{role}") if role
      res = %(#{res} xreflabel="#{reftext}") if reftext
      res
    end

    def doctype_declaration root_tag_name
      %(<!DOCTYPE #{root_tag_name} PUBLIC "-//OASIS//DTD DocBook XML V4.5//EN" "http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd">)
    end

    def document_info_element doc, info_tag_prefix
      super doc, info_tag_prefix, true
    end

    def document_ns_attributes doc
      (doc.attr? 'noxmlns') ? nil : ' xmlns="http://docbook.org/ns/docbook"'
    end
  end
end
