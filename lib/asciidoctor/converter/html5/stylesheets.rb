require 'asciidoctor/converter/html5/component'

module Asciidoctor
  module Converter
    module Html5
      class Stylesheets < Component
        DEFAULT_WEB_FONT = 'Open+Sans:300,300italic,400,400italic,600,600italic%7C'\
                           'Noto+Serif:400,400italic,700,700italic%7CDroid+Sans+Mono:400,700'

        alias_method :document, :node

        def initialize(document, void_element_slash, stylesheets)
          super(document, void_element_slash)
          @stylesheets = stylesheets
        end

        def render
          if DEFAULT_STYLESHEET_KEYS.include?(stylesheet)
            output(web_font_include_html) if web_fonts
            output(default_stylesheet_html)
          elsif document.attr?('stylesheet')
            output(custom_stylesheet_html)
          end

          output(source_highlighter_import_html)
          output(icon_font_import_html) if document.attr?('icons', 'font')
        end

        private

        def coderay_stylesheet_import_html
          if document.attr('coderay-css', 'class') == 'class'
            if link_css?
              coderay_stylesheet_uri = document.normalize_web_path(
                @stylesheets.coderay_stylesheet_name,
                styles_directory,
                false
              )

              %(<link rel="stylesheet" href="#{coderay_stylesheet_uri}"#{void_element_slash}>)
            else
              @stylesheets.embed_coderay_stylesheet
            end
          end
        end

        def pygments_stylesheet_import_html
          if document.attr('pygments-css', 'class') == 'class'
            pygments_style = document.attr('pygments-style')

            if link_css?
              pygments_stylesheet_name = @stylesheets.pygments_stylesheet_name(pygments_style)
              pygments_stylesheet_uri = document.normalize_web_path(pygments_stylesheet_name, styles_directory, false)
              %(<link rel="stylesheet" href="#{pygments_stylesheet_uri}"#{void_element_slash}>)
            else
              @stylesheets.embed_pygments_stylesheet(pygments_style)
            end
          end
        end

        def source_highlighter_import_html
          case document.attr('source-highlighter')
          when 'coderay'
            coderay_stylesheet_import_html
          when 'pygments'
            pygments_stylesheet_import_html
          end
        end

        def icon_font_import_html
          if document.attr?('iconfont-remote')
            cdn_base = "#{asset_uri_scheme}//cdnjs.cloudflare.com/ajax/libs"
            font_awesome_uri = "#{cdn_base}/font-awesome/#{FONT_AWESOME_VERSION}/css/font-awesome.min.css"
            icon_font_uri = document.attr('iconfont-cdn', font_awesome_uri)
            %(<link rel="stylesheet" href="#{icon_font_uri}"#{void_element_slash}>)
          else
            icon_font_name = document.attr('iconfont-name', 'font-awesome')
            iconfont_stylesheet = %(#{icon_font_name}.css)
            stylesheet_uri = document.normalize_web_path(iconfont_stylesheet, styles_directory, false)
            %(<link rel="stylesheet" href="#{stylesheet_uri}"#{void_element_slash}>)
          end
        end

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

        def web_font_include_html
          web_font_family = web_fonts || DEFAULT_WEB_FONT
          web_font_uri = "#{asset_uri_scheme}//fonts.googleapis.com/css?family=#{web_font_family}"
          %(<link rel="stylesheet" href="#{web_font_uri}"#{void_element_slash}>)
        end

        def link_css?
          document.attr?('linkcss')
        end

        def asset_uri_scheme
          scheme = document.attr('asset-uri-scheme', 'https')

          if scheme.empty? || scheme[-1] == ':'
            scheme
          else
            "#{scheme}:"
          end
        end

        def web_fonts
          document.attr('webfonts')
        end
      end
    end
  end
end
