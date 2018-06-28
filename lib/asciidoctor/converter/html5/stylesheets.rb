module Asciidoctor
  module Converter
    module Html5
      class Stylesheets
        DEFAULT_WEB_FONT = 'Open+Sans:300,300italic,400,400italic,600,600italic%7C'\
                         'Noto+Serif:400,400italic,700,700italic%7CDroid+Sans+Mono:400,700'

        def initialize(document, stylesheets, opts = {})
          @document = document
          @opts = opts
          @stylesheets = stylesheets
        end

        def to_html
          result = []

          if default_stylesheet?
            result << web_font_include_html if web_fonts?
            result << default_stylesheet_html
          elsif stylesheet?
            result << custom_stylesheet_html
          end

          result
        end

        private

        def default_stylesheet_html
          if link_css?
            default_stylesheet_uri = document.normalize_web_path(DEFAULT_STYLESHEET_NAME, styles_directory, false)
            %(<link rel="stylesheet" href="#{default_stylesheet_uri}"#{void_element_slash}>)
          else
            @stylesheets.embed_primary_stylesheet
          end
        end

        def styles_directory
          document.attr('stylesdir', '')
        end

        def custom_stylesheet_html
          if link_css?
            stylesheet_web_path = document.normalize_web_path(stylesheet, styles_directory)
            %(<link rel="stylesheet" href="#{stylesheet_web_path}"#{void_element_slash}>)
          else
            embedded_custom_stylesheet_html
          end
        end

        def embedded_custom_stylesheet_html
          stylesheet_system_path = document.normalize_system_path(stylesheet, styles_directory)

          stylesheet_contents = document.read_asset(
            stylesheet_system_path,
            :warn_on_failure => true,
            :label => 'stylesheet'
          )

          "<style>\n#{stylesheet_contents}\n</style>"
        end

        def stylesheet
          document.attr('stylesheet')
        end

        def void_element_slash
          @opts[:void_element_slash]
        end

        def web_font_include_html
          web_font_uri = "#{asset_uri_scheme}//fonts.googleapis.com/css?family=#{web_font_family}"
          %(<link rel="stylesheet" href="#{web_font_uri}"#{void_element_slash}>)
        end

        def document
          @document
        end

        def link_css?
          document.attr?('linkcss')
        end

        def asset_uri_scheme
          scheme = document.attr('asset-uri-scheme', 'https')

          if scheme[-1] == ':'
            scheme
          else
            "#{scheme}:"
          end
        end

        def stylesheet?
          document.attr?('stylesheet')
        end

        def default_stylesheet?
          DEFAULT_STYLESHEET_KEYS.include?(stylesheet)
        end

        def web_fonts
          document.attr('webfonts')
        end

        def web_fonts?
          !!web_fonts
        end

        def web_font_family
          web_fonts || DEFAULT_WEB_FONT
        end
      end
    end
  end
end
