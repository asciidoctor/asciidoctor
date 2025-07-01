# frozen_string_literal: true

autoload :Date, 'date' unless RUBY_ENGINE == 'opal'

module Asciidoctor
# A built-in {Converter} implementation that generates HTML 5 output
# that maximizes the use of semantic constructs.
class Converter::SemanticHtml5Converter < Converter::Base
  register_for 'semantic-html5'

  def initialize backend, opts = {}
    @backend = backend
    syntax = opts[:htmlsyntax] == 'xml' ? 'xml' : 'html'
    init_backend_traits basebackend: 'html', filetype: 'html', htmlsyntax: syntax, outfilesuffix: '.html', supports_templates: true
  end

  def convert_embedded node
    result = []
    if (header = generate_header node)
      result << header
    end
    result << node.content
    result.join LF
  end

  def convert_section node
    doc_attrs = node.document.attributes
    if node.caption
      title = node.captioned_title
    elsif (section_numbering = generate_section_numbering node)
      title = %(#{section_numbering} #{node.title})
    else
      title = node.title
    end
    id = node.id
    if doc_attrs['sectlinks']
      title = %(<a class="link" href="##{id}">#{title}</a>)
    end
    if doc_attrs['sectanchors']
      if doc_attrs['sectanchors'] == 'after'
        title = %(#{title}<a class="anchor" href="##{id}"></a>)
      else
        title = %(<a class="anchor" href="##{id}"></a>#{title})
      end
    end
    attributes = common_html_attributes id, node.role
    level = node.level
    result = []
    result << %(<section#{attributes}>)
    result << %(<h#{level + 1}>#{title}</h#{level + 1}>)
    result << node.content if node.blocks?
    result << '</section>'
    result.join LF
  end

  def convert_paragraph node
    attributes = common_html_attributes node.id, node.role
    if node.title?
      %(<p#{attributes}>
<strong class="title">#{node.title}</strong>
#{node.content}
</p>)
    else
      %(<p#{attributes}>
#{node.content}
</p>)
    end
  end

  def convert_listing node
    caption = (caption = node.caption) ? %(<span class="label">#{caption}</span> ) : ''
    title = node.title? ? %(<figcaption>#{caption}#{node.title}</figcaption>\n) : ''
    attributes = common_html_attributes node.id, node.role, 'listing'
    nowrap = (node.option? 'nowrap') || !(node.document.attr? 'prewrap')
    if node.style == 'source'
      lang = node.attr 'language'
      if (syntax_hl = node.document.syntax_highlighter)
        opts = syntax_hl.highlight? ? {
          css_mode: ((doc_attrs = node.document.attributes)[%(#{syntax_hl.name}-css)] || :class).to_sym,
          style: doc_attrs[%(#{syntax_hl.name}-style)],
        } : {}
        opts[:nowrap] = nowrap
        content = syntax_hl.format node, lang, opts
      else
        content = %(<code#{lang ? %( data-lang="#{lang}") : ''}>#{node.content || ''}</code>)
      end
    else
      content = node.content || ''
    end
    %(<figure#{attributes}>
#{title}<pre#{nowrap ? ' class="nowrap"' : ''}>#{content}</pre>
</figure>)
  end

  def convert_thematic_break node
    '<hr>'
  end

  def convert_table node
    # Adds content to a nested array and initiates new nested arrays when an index does not exist already
    convert_util_array_dynamic_add_child_array = lambda do |arr, index, content|
      if arr[index] == nil
        arr.push([content])
      else
        arr[index].push(content)
      end
    end

    result = []
    id_attribute = node.id ? %( id="#{node.id}") : ''
    frame = 'ends' if (frame = node.attr 'frame', 'all', 'table-frame') == 'topbot'
    classes = ['tableblock', %(frame-#{frame}), %(grid-#{node.attr 'grid', 'all', 'table-grid'})]
    if (stripes = node.attr 'stripes', nil, 'table-stripes')
      classes << %(stripes-#{stripes})
    end
    width_attribute = ''
    if (autowidth = node.option? 'autowidth') && !(node.attr? 'width')
      classes << 'fit-content'
    elsif (tablewidth = node.attr 'tablepcwidth') == 100
      classes << 'stretch'
    else
      width_attribute = %( width="#{tablewidth}%")
    end
    classes << (node.attr 'float') if node.attr? 'float'
    if (role = node.role)
      classes << role
    end
    class_attribute = %( class="#{classes.join ' '}")

    result << %(<table#{id_attribute}#{class_attribute}#{width_attribute}>)
    if node.title?
      result << %(<caption class="title">#{node.captioned_title}</caption>)
    end
    if (node.attr 'rowcount') > 0
      slash = @void_element_slash
      result << '<colgroup>'
      if autowidth
        result += (Array.new node.columns.size, %(<col#{slash}>))
      else
        node.columns.each do |col|
          result << ((col.option? 'autowidth') ? %(<col#{slash}>) : %(<col style="width: #{col.attr 'colpcwidth'}%"#{slash}>))
        end
      end
      result << '</colgroup>'

      # A table can contain nested column and row level headings. The two array declarations help us to keep track of them.
      # Containing the column level heading cells in a nested array. The index of 'header_titles_by_column' represents the index number of a column. It reveils a sub array holding the cell text of all column level heading cells belonging to the column.
      # Example: [['cell text of column level heading cell A', ['cell text of column level heading cell B']]
      header_titles_by_column = Array.new
      # Containing the column level heading cells in a nested array. The index of 'header_titles_by_row' represents the index number of a row. It reveils a sub array holding the cell text of all row level heading cells belonging to the row.
      # Example: [['cell text of row level heading cell A', ['cell text of row level heading cell B']]
      header_titles_by_row = Array.new

      # Containing the number of columns per row which we need as an offset so we assign the non-heading cells the correct text of their corresponding heading cells. The index of 'reserved_columns_per_row_for_headings' represents the index number of a row. It reveils a number indicating the amount of cells defined in an earlier row spawning into this one.
      # Example: [3,3]
      reserved_columns_per_row_for_headings = Array.new

      # There are three possible row sections: 'header', 'body' and 'footer' AsciiDoc knows. In order to give each non-heading cells info about the corresponding heading cells, the algorithm needs to see all rows from the table comming from the same array.
      # The variable `current_row_index` simulates exactly that. The loop variable 'row_index' is unsufficient as it is scoped to just one array at a time.
      current_row_index = 0

      # TODO: make the following tests have `data-column-header` and `data-row-header` HTML attribute on non-heading cells populated properly:
      #  - table-ultracomplex-combined-non-heading-cell-at-row-begin.adoc
      #  - table-ultracomplex-combined-non-heading-cell-in-body.adoc
      node.rows.to_h.each do |tsec, rows|
        next if rows.empty?
        result << %(<t#{tsec}>)
        rows.each_with_index do |row, row_index|
          tr_html = []
          # result << '<tr>'
          # Make aware of cells that span multiple columns per row and were defined in an earlier row as these influence the normalized index of columns in this row
          logger.debug %(Starting with first cell in row #{current_row_index} (#{tsec} row #{row_index}))
          logger.debug %(Cells: #{rows[row_index].map{|cell| (cell.class == Hash ? "Cell [SHADOW CELL]" : cell.text)}})
          row.each_with_index do |cell, cell_index|
            logger.debug %(  index of cell: #{cell_index}, cell content: #{(cell.class == Hash ? "Cell [SHADOW CELL]" : cell.text)})
            cell_is_shadow = false
            duplicated_row_heading = false
            duplicated_column_heading = false
            if cell.class == Hash
              logger.debug '    is virtual column added by cells from previous rows spawning into the current row'
              cell_is_shadow = true
              duplicated_row_heading = cell['duplicated_row_heading']
              duplicated_column_heading = cell['duplicated_column_heading']
              cell = cell['cell']
            end

            # deal with heading cells
            # TODO: fix duplication like `ch_a - ch_a` - ch_aa` (two level deep column headings where one spawns two rows) to `ch_a - ch_aa` (target) in the headers_titles_by_column
            #  this bug arises when AsciiDoc starts supporting more than just one header column inside thead
            #  developers can add a second row in thead array inside `convert_table` function to debug and fix this bug before it arises
            #  this bug has probably been fixed by introducing variable 'duplicated_column_heading'
            if (tsec == :head || cell.style == :header)
              # cell is a heading cell so we need to add their text to our lists of column and row level headings.

              # this condition probably prevents duplications like this `ch_a - ch_a` - ch_aa` in column headers (header_titles_by_column)
              if duplicated_column_heading == false
                logger.debug %(    add "#{cell.text}" at column index position #{cell_index} to header_titles_by_column)
                convert_util_array_dynamic_add_child_array[header_titles_by_column, cell_index, cell]
              end

              # this condition prevents duplications like this `rh_a - rh_a - rh_ad` in row headers (header_titles_by_row)
              if duplicated_row_heading == false
                logger.debug %(      add "#{cell.text}" at row index position #{current_row_index} to header_titles_by_row)
                convert_util_array_dynamic_add_child_array[header_titles_by_row, current_row_index, cell]
              end
            end

            # deal with virtual/shadow cells/columns to create
            if cell_is_shadow == false
              if cell.colspan != nil
                # account for cells spawning multiple columns by resolving their colspan value to separate cells internally
                (1..cell.colspan-1).each do | index |
                  logger.debug %(      add virtual cell before column index #{cell_index+index} to the current row)
                  shadow_cell = {
                    'cell' => cell,
                    'shadow' => true,
                    'duplicated_column_heading' => false,
                    'duplicated_row_heading' => (index == 0 ? false : true),
                    'heading' => (tsec == :head || cell.style == :header ? true : false)
                  }
                  rows[row_index].insert(cell_index+index, shadow_cell)
                end
              end

              if cell.rowspan != nil
                # account for cells spawning multiple rows by resolving their rowspan value to separate cells internally
                (1..cell.rowspan-1).each do | rowspan_index |
                  colspan = (cell.colspan ? cell.colspan : 1)
                  (0..colspan-1).each do | colspan_index |
                    if rows.count > row_index+rowspan_index
                      logger.debug %(        add it to next row #{row_index+rowspan_index} before column index #{cell_index+colspan_index})
                      shadow_cell = {
                        'cell' => cell,
                        'shadow' => true,
                        'duplicated_column_heading' => (rowspan_index == 0 ? false : true),
                        'duplicated_row_heading' => (colspan_index == 0 ? false : true),
                        'heading' => (tsec == :head || cell.style == :header ? true : false)
                      }
                      rows[row_index+rowspan_index].insert(cell_index+colspan_index, shadow_cell)
                    end
                  end
                end
              end
            end

            # Header cells which are declared as shadow (hidden) cells are not necessary in the HTML output for responsive tables (turning multi column layout into two-column layout on small screens), so we skip the HTML code generation for them
            if cell_is_shadow && (tsec == :head || cell.style == :header)
              next
            end

            if tsec == :head
              cell_content = cell.text
            else
              case cell.style
              when :asciidoc
                cell_content = %(<div class="content">#{cell.content}</div>)
              when :literal
                cell_content = %(<div class="literal"><pre>#{cell.text}</pre></div>)
              else
                cell_content = (cell_content = cell.content).empty? ? '' : %(<p class="tableblock">#{cell_content.join '</p>
<p class="tableblock">'}</p>)
              end
            end

            cell_tag_name = (tsec == :head || cell.style == :header ? 'th' : 'td')
            cell_class_attribute = %( class="tableblock halign-#{cell.attr 'halign'} valign-#{cell.attr 'valign'}#{( cell_is_shadow == true ? ' shadow-cell': '')}")
            if cell_is_shadow
              cell_colspan_attribute = ''
              cell_rowspan_attribute = ''
              cell_html_attributes = ' hidden'
            else
              cell_colspan_attribute = (cell.colspan && cell_is_shadow == false ? %( colspan="#{cell.colspan}") : '')
              cell_rowspan_attribute = (cell.rowspan && cell_is_shadow == false ? %( rowspan="#{cell.rowspan}") : '')
              cell_html_attributes = ''
            end
            cell_scope_attribute = (tsec == :head ? %( scope="col") : (cell.style == :header ? %( scope="row") : ''))
            cell_style_attribute = (node.document.attr? 'cellbgcolor') ? %( style="background-color: #{node.document.attr 'cellbgcolor'};") : ''

            if cell_tag_name == 'td'
              cell_data_column_header_separator = ' ' + (node.document.attributes['table-cell-data-column-header-separator'] || '-') + ' '
              cell_data_column_header = ' data-column-header="'
              cell_data_column_header += (header_titles_by_column[cell_index] != nil ? header_titles_by_column[cell_index].map{|cell| cell.text}.join(cell_data_column_header_separator) : '')
              cell_data_column_header += '"'

              cell_data_row_header_separator = ' ' + (node.document.attributes['table-cell-data-row-header-separator'] || '-') + ' '
              cell_data_row_header = ' data-row-header="'
              cell_data_row_header += (header_titles_by_row[current_row_index] != nil ? header_titles_by_row[current_row_index].map{|cell| cell.text}.join(cell_data_row_header_separator) : '')
              cell_data_row_header += '"'
            else
              cell_data_column_header = ''
              cell_data_row_header = ''
            end
            # if cell has colspan specified and is not a shadow cell
            if cell.colspan != nil && cell_is_shadow == false
              # then add it without `cell_data_column_header` and `cell_data_row_header`
              tr_html << %(<#{cell_tag_name}#{cell_html_attributes}#{cell_scope_attribute}#{cell_class_attribute}#{cell_colspan_attribute}#{cell_rowspan_attribute}#{cell_style_attribute}>#{cell_content}</#{cell_tag_name}>)
              # and add a shadow cell for it because cells with colspan and rowspan must be hidden in two-column layout and replaced by their shadow cells like this one. Shadow cells always have `cell_data_column_header` and `cell_data_row_header` HTML attributes
              tr_html << %(<#{cell_tag_name} hidden #{cell_html_attributes}#{cell_scope_attribute}#{cell_class_attribute}#{cell_style_attribute}#{cell_data_column_header}#{cell_data_row_header}>#{cell_content}</#{cell_tag_name}>)
            else
              tr_html << %(<#{cell_tag_name}#{cell_html_attributes}#{cell_scope_attribute}#{cell_class_attribute}#{cell_colspan_attribute}#{cell_rowspan_attribute}#{cell_style_attribute}#{cell_data_column_header}#{cell_data_row_header}>#{cell_content}</#{cell_tag_name}>)
            end
          end
          
          if header_titles_by_row[current_row_index] != nil && tsec != :head
            cell_data_row_header_separator = ' ' + (node.document.attributes['table-cell-data-row-header-separator'] || '-') + ' '
            cell_data_row_header = ' data-row-header="'
            cell_data_row_header += header_titles_by_row[current_row_index].map{|cell| cell.text}.join(cell_data_row_header_separator)
            cell_data_row_header += '"'
          else
            cell_data_row_header = ''
          end
          result << %(<tr#{cell_data_row_header}>)
          result << tr_html.join(LF)
          result << '</tr>'

          current_row_index += 1
        end
        result << %(</t#{tsec}>)
      end
    end
    result << '</table>'
    result.join LF
  end

  def convert_image node
    roles = []
    roles << node.role if node.role
    roles << %(text-#{node.attr 'align'}) if node.attr? 'align'
    roles << (node.attr 'float').to_s if node.attr? 'float'
    role = roles.join ' '
    attributes = common_html_attributes node.id, role.empty? ? nil : role
    size = []
    size << %( width="#{node.attr 'width'}") if node.attr? 'width'
    size << %( height="#{node.attr 'height'}") if node.attr? 'height'
    size = size.join
    target = node.attr 'target'
    link_start = %(<a href="#{node.attr 'link'}">) if node.attr? 'link'
    link_end = %(</a>) if node.attr? 'link'

    if node.title?
      %(<figure#{attributes}>
#{link_start}<img src="#{target}" alt="#{encode_attribute_value node.alt}"#{size} />#{link_end}
<figcaption>#{node.captioned_title}</figcaption>
</figure>)
    else
      %(#{link_start}<img src="#{target}" alt="#{encode_attribute_value node.alt}"#{attributes}#{size} />#{link_end})
    end
  end

  def convert_inline_image node
    roles = []
    roles << node.role if node.role
    roles << %(text-#{node.attr 'align'}) if node.attr? 'align'
    roles << (node.attr 'float').to_s if node.attr? 'float'
    role = roles.join ' '
    attributes = common_html_attributes node.id, role.empty? ? nil : role
    size = []
    size << %( width="#{node.attr 'width'}") if node.attr? 'width'
    size << %( height="#{node.attr 'height'}") if node.attr? 'height'
    size = size.join
    target = node.target
    title = %( title="#{node.attr 'title'}") if node.attr? 'title'
    %(<img src="#{target}" alt="#{encode_attribute_value node.alt}"#{title}#{attributes}#{size} />)
  end

  def convert_inline_anchor node
    case node.type
    when :link
      attrs = node.id ? [%( id="#{node.id}")] : []
      attrs << %( class="#{node.role}") if node.role
      attrs << %( title="#{node.attr 'title'}") if node.attr? 'title'
      %(<a href="#{node.target}"#{(append_link_constraint_attrs node, attrs).join}>#{node.text}</a>)
    else
      logger.warn %(unknown anchor type: #{node.type.inspect})
      nil
    end
  end

  def convert_inline_kbd node
    if (keys = node.attr 'keys').size == 1
      %(<kbd>#{keys[0]}</kbd>)
    else
      %(<span class="keyseq"><kbd>#{keys.join '</kbd>+<kbd>'}</kbd></span>)
    end
  end

  def convert_inline_quoted node
    attributes = common_html_attributes node.id, node.role
    case node.type
    when :strong
      %(<strong#{attributes}>#{node.text}</strong>)
    when :emphasis
      %(<em#{attributes}>#{node.text}</em>)
    when :monospaced
      %(<code#{attributes}>#{node.text}</code>)
    when :mark
      %(<mark#{attributes}>#{node.text}</mark>)
    when :superscript
      %(<sup#{attributes}>#{node.text}</sup>)
    when :subscript
      %(<sub#{attributes}>#{node.text}</sub>)
    when :single
      attributes = common_html_attributes node.id, node.role, 'singlequote'
      %(<span#{attributes}>&#8216;#{node.text}&#8217;</span>)
    when :double
      attributes = common_html_attributes node.id, node.role, 'doublequote'
      %(<span#{attributes}>&#8220;#{node.text}&#8221;</span>)
    else
      %(<span#{attributes}>#{node.text}</span>)
    end
  end

  def convert_inline_break node
    %(#{node.text}<br>)
  end

  def convert_inline_button node
    %(<span class="button">#{node.text}</span>)
  end

  def convert_inline_menu node
    caret = '&#160;<b class="caret">&#8250;</b> '
    submenu_joiner = %(</b>#{caret}<b class="submenu">)
    menu = node.attr 'menu'
    if (submenus = node.attr 'submenus').empty?
      if (menuitem = node.attr 'menuitem')
        %(<span class="menuseq"><b class="menu">#{menu}</b>#{caret}<b class="menuitem">#{menuitem}</b></span>)
      else
        %(<span class="menuseq"><b class="menu">#{menu}</b></span>)
      end
    else
      %(<span class="menuseq"><b class="menu">#{menu}</b>#{caret}<b class="submenu">#{submenus.join submenu_joiner}</b>#{caret}<b class="menuitem">#{node.attr 'menuitem'}</b></span>)
    end
  end

  def generate_section_numbering node
    level = node.level
    doc_attrs = node.document.attributes

    return unless node.numbered && level <= (doc_attrs['sectnumlevels'] || 3).to_i

    if level < 2 && node.document.doctype == 'book'
      case node.sectname
      when 'chapter'
        %(#{(signifier = doc_attrs['chapter-signifier']) ? "#{signifier} " : ''}<span class="sectnum">#{node.sectnum}</span>)
      when 'part'
        %(#{(signifier = doc_attrs['part-signifier']) ? "#{signifier} " : ''}<span class="sectnum">#{node.sectnum nil, ':'}</span>)
      else
        %(<span class="sectnum">#{node.sectnum}</span>)
      end
    else
      %(<span class="sectnum">#{node.sectnum}</span>)
    end
  end

  def generate_header node
    return unless node.header? && !node.noheader

    result = ['<header>']
    if (doctitle = generate_document_title node)
      result << doctitle
    end
    if (authors = generate_authors node)
      result << authors
    end
    if (revision = generate_revision node)
      result << revision
    end
    result << '</header>'
    result.join LF
  end

  def generate_document_title node
    return if node.notitle

    doctitle = node.doctitle partition: true, sanitize: true
    attributes = common_html_attributes node.id, node.role
    %(<h1#{attributes}>#{doctitle.main}#{doctitle.subtitle? ? %( <small class="subtitle">#{doctitle.subtitle}</small>) : ''}</h1>)
  end

  def generate_authors node
    return if node.authors.empty?

    if node.authors.length == 1
      %(<p class="byline">
#{format_author node, node.authors.first}
</p>)
    else
      result = ['<ul class="byline">']
      node.authors.each do |author|
        result << "<li>#{format_author node, author}</li>"
      end
      result << '</ul>'
      result.join LF
    end
  end

  def generate_revision node
    return unless (node.attr? 'revnumber') || (node.attr? 'revdate') || (node.attr? 'revremark')

    revision_date = if (revdate = node.attr 'revdate')
                      date = ::Date._parse revdate
                      if (date.key? :year) || (date.key? :mon) || (date.key? :mday)
                        date_parts = []
                        date_parts << (date[:year]).to_s if date.key? :year
                        date_parts << (date[:mon].to_s.rjust 2, '0').to_s if date.key? :mon
                        date_parts << (date[:mday].to_s.rjust 2, '0').to_s if date.key? :mday
                        %(<time datetime="#{date_parts.join '-'}">#{revdate}</time>)
                      else
                        revdate
                      end
                    else
                      ''
                    end
    %(<table class="revision">
<thead>
<tr>
<th>Version</th>
<th>Date</th>
<th>Remark</th>
</tr>
</thead>
<tbody>
<tr>
<td data-title="#{node.attr 'version-label'}">#{node.attr 'revnumber'}</td>
<td data-title="Date">#{revision_date}</td>
<td data-title="Remark">#{node.attr 'revremark'}</td>
</tr>
</tbody>
</table>)
  end

  def format_author node, author
    in_context 'author' do
      %(<span class="author">#{node.sub_replacements author.name}#{author.email ? %( #{node.sub_macros author.email}) : ''}</span>)
    end
  end

  def in_context name
    (@convert_context ||= []).push name
    result = yield
    @convert_context.pop
    result
  end

  def common_html_attributes id, role, default_role = nil
    roles = default_role ? [default_role] : []
    roles << role if role
    %(#{id ? %( id="#{id}") : ''}#{roles.empty? ? '' : %( class="#{roles.join ' '}")})
  end

  def append_link_constraint_attrs node, attrs = []
    link_types = []
    link_types << 'author' if (@convert_context || []).last == 'author'
    link_types << 'nofollow' if node.option? 'nofollow'
    if (window = node.attributes['window'])
      attrs << %( target="#{window}")
      link_types << 'noopener' if window == '_blank' || (node.option? 'noopener')
    end
    attrs << %( rel="#{link_types.join ' '}") unless link_types.empty?
    attrs
  end

  def encode_attribute_value val
    (val.include? '"') ? (val.gsub '"', '&quot;') : val
  end
end
end
