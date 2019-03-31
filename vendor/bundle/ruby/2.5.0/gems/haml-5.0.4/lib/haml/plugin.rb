# frozen_string_literal: true
module Haml

  # This module makes Haml work with Rails using the template handler API.
  class Plugin
    def handles_encoding?; true; end

    def compile(template)
      options = Haml::Template.options.dup
      if template.respond_to?(:type)
        options[:mime_type] = template.type
      elsif template.respond_to? :mime_type
        options[:mime_type] = template.mime_type
      end
      options[:filename] = template.identifier
      Haml::Engine.new(template.source, options).compiler.precompiled_with_ambles(
        [],
        after_preamble: '@output_buffer = output_buffer ||= ActionView::OutputBuffer.new if defined?(ActionView::OutputBuffer)',
      )
    end

    def self.call(template)
      new.compile(template)
    end

    def cache_fragment(block, name = {}, options = nil)
      @view.fragment_for(block, name, options) do
        eval("_hamlout.buffer", block.binding)
      end
    end
  end
end

ActionView::Template.register_template_handler(:haml, Haml::Plugin)
