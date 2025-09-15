module Asciidoctor

  class StemAdapter::TransformLatexmathMathjaxHtml5
    include Asciidoctor::StemAdapter::PluginBase
    register_for :latexmath, :mathjax, :html5

    public
    def docinfo? location
      location == :footer
    end

    def docinfo location, doc, opts
      node = doc
      eqnums_val = node.attr 'eqnums', 'none'
      eqnums_val = 'AMS' if eqnums_val.empty?
      eqnums_opt = %( equationNumbers: { autoNumber: "#{eqnums_val}" } )

      # IMPORTANT inspect calls on delimiter arrays are intentional for JavaScript compat (emulates JSON.stringify)
      %(<script type="text/x-mathjax-config">
  MathJax.Hub.Config({
    messageStyle: "none",
    tex2jax: {
      inlineMath: [#{INLINE_MATH_DELIMITERS[:latexmath].inspect}],
      displayMath: [#{BLOCK_MATH_DELIMITERS[:latexmath].inspect}],
      ignoreClass: "nostem|nolatexmath"
    },
    asciimath2jax: {
      delimiters: [#{BLOCK_MATH_DELIMITERS[:asciimath].inspect}],
      ignoreClass: "nostem|noasciimath"
    },
    TeX: {#{eqnums_opt}}
  })
  MathJax.Hub.Register.StartupHook("AsciiMath Jax Ready", function () {
    MathJax.InputJax.AsciiMath.postfilterHooks.Add(function (data, node) {
      if ((node = data.script.parentNode) && (node = node.parentNode) && node.classList.contains("stemblock")) {
        data.math.root.display = "block"
      }
      return data
    })
  })
  </script>
  <script src="#{opts[:asset_uri][:mathjax_uri]}"></script>
  )
    end

    def convert node
      id_attribute = node.id ? %( id="#{node.id}") : ''
      title_element = node.title? ? %(<div class="title">#{node.title}</div>\n) : ''
      open, close = BLOCK_MATH_DELIMITERS[style = node.style.to_sym]
      if (equation = node.content)
        if style == :asciimath && (equation.include? LF)
          br = %(#{LF}<br#{@void_element_slash}>)
          equation = equation.gsub(StemAdapter::StemBreakRx) { %(#{close}#{br * (($&.count LF) - 1)}#{LF}#{open}) }
        end
        unless (equation.start_with? open) && (equation.end_with? close)
          equation = %(#{open}#{equation}#{close})
        end
      else
        equation = ''
      end
      %(<div#{id_attribute} class="stemblock#{(role = node.role) ? " #{role}" : ''}">
  #{title_element}<div class="content">
  #{equation}
  </div>
  </div>)
    end

  end
end
