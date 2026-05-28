# frozen_string_literal: true

module Asciidoctor
class StemAdapter::MathJaxAdapter
  include StemAdapter

  register_for 'mathjax'

  StemBreakRx = / *\\\n(?:\\?\n)*|\n\n+/

  def docinfo? location
    location == :footer
  end

  def docinfo location, doc, opts
    cdn_base_url = opts[:cdn_base_url]
    eqnums_val = doc.attr 'eqnums', 'none'
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
<script src="#{cdn_base_url}/mathjax/#{MATHJAX_VERSION}/MathJax.js?config=TeX-MML-AM_CHTML"></script>)
  end

  def convert node, opts = {}
    if node.block?
      open, close = BLOCK_MATH_DELIMITERS[style = node.style.to_sym]
      if (equation = node.content)
        if style == :asciimath && (equation.include? LF)
          void_element_slash = node.document.attr('htmlsyntax') == 'xml' ? '/' : ''
          br = %(#{LF}<br#{void_element_slash}>)
          equation = equation.gsub(StemBreakRx) { %(#{close}#{br * (($&.count LF) - 1)}#{LF}#{open}) }
        end
        unless (equation.start_with? open) && (equation.end_with? close)
          equation = %(#{open}#{equation}#{close})
        end
      else
        equation = ''
      end
      equation
    else
      open, close = INLINE_MATH_DELIMITERS[node.type]
      %(#{open}#{node.text}#{close})
    end
  end

  def format node, opts = {}
    id_attribute = node.id ? %( id="#{node.id}") : ''
    title_element = node.title? ? %(<div class="title">#{node.title}</div>\n) : ''
    %(<div#{id_attribute} class="stemblock#{(role = node.role) ? " #{role}" : ''}">
#{title_element}<div class="content">
#{convert node, opts}
</div>
</div>)
  end
end
end
