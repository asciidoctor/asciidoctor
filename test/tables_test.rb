# encoding: UTF-8
unless defined? ASCIIDOCTOR_PROJECT_DIR
  $: << File.dirname(__FILE__); $:.uniq!
  require 'test_helper'
end

context 'Tables' do

  context 'PSV' do
    test 'renders simple psv table' do
      input = <<-EOS
|=======
|A |B |C
|a |b |c
|1 |2 |3
|=======
      EOS
      cells = [%w(A B C), %w(a b c), %w(1 2 3)]
      doc = document_from_string input, :header_footer => false
      table = doc.blocks[0]
      assert 100, table.columns.map {|col| col.attributes['colpcwidth'] }.reduce(:+)
      output = doc.convert
      assert_css 'table', output, 1
      assert_css 'table.tableblock.frame-all.grid-all.spread', output, 1
      assert_css 'table > colgroup > col[style*="width: 33.3333%"]', output, 2
      assert_css 'table > colgroup > col:last-of-type[style*="width: 33.3334%"]', output, 1
      assert_css 'table tr', output, 3
      assert_css 'table > tbody > tr', output, 3
      assert_css 'table td', output, 9
      assert_css 'table > tbody > tr > td.tableblock.halign-left.valign-top > p.tableblock', output, 9
      cells.each_with_index {|row, rowi|
        assert_css "table > tbody > tr:nth-child(#{rowi + 1}) > td", output, row.size
        assert_css "table > tbody > tr:nth-child(#{rowi + 1}) > td > p", output, row.size
        row.each_with_index {|cell, celli|
          assert_xpath "(//tr)[#{rowi + 1}]/td[#{celli + 1}]/p[text()='#{cell}']", output, 1
        }
      }
    end

    test 'renders caption on simple psv table' do
      input = <<-EOS
.Simple psv table
|=======
|A |B |C
|a |b |c
|1 |2 |3
|=======
      EOS
      output = render_embedded_string input
      assert_xpath '/table/caption[@class="title"][text()="Table 1. Simple psv table"]', output, 1
      assert_xpath '/table/caption/following-sibling::colgroup', output, 1
    end

    test 'only increments table counter for tables that have a title' do
      input = <<-EOS
.First numbered table
|=======
|1 |2 |3
|=======

|=======
|4 |5 |6
|=======

.Second numbered table
|=======
|7 |8 |9
|=======
      EOS
      output = render_embedded_string input
      assert_css 'table:root', output, 3
      assert_xpath '(/table)[1]/caption', output, 1
      assert_xpath '(/table)[1]/caption[text()="Table 1. First numbered table"]', output, 1
      assert_xpath '(/table)[2]/caption', output, 0
      assert_xpath '(/table)[3]/caption', output, 1
      assert_xpath '(/table)[3]/caption[text()="Table 2. Second numbered table"]', output, 1
    end

    test 'renders explicit caption on simple psv table' do
      input = <<-EOS
[caption="All the Data. "]
.Simple psv table
|=======
|A |B |C
|a |b |c
|1 |2 |3
|=======
      EOS
      output = render_embedded_string input
      assert_xpath '/table/caption[@class="title"][text()="All the Data. Simple psv table"]', output, 1
      assert_xpath '/table/caption/following-sibling::colgroup', output, 1
    end

    test 'ignores escaped separators' do
      input = <<-EOS
|===
|A \\| here| a \\| there
|===
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > tbody > tr', output, 1
      assert_css 'table > tbody > tr > td', output, 2
      assert_xpath '/table/tbody/tr/td[1]/p[text()="A | here"]', output, 1
      assert_xpath '/table/tbody/tr/td[2]/p[text()="a | there"]', output, 1
    end

    test 'preserves escaped delimiters at the end of the line' do
      input = <<-EOS
[%header,cols="1,1"]
|====
|A |B\\|
|A1 |B1\\|
|A2 |B2\\|
|====
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > thead > tr', output, 1
      assert_css 'table > thead > tr:nth-child(1) > th', output, 2
      assert_xpath '/table/thead/tr[1]/th[2][text()="B|"]', output, 1
      assert_css 'table > tbody > tr', output, 2
      assert_css 'table > tbody > tr:nth-child(1) > td', output, 2
      assert_xpath '/table/tbody/tr[1]/td[2]/p[text()="B1|"]', output, 1
      assert_css 'table > tbody > tr:nth-child(2) > td', output, 2
      assert_xpath '/table/tbody/tr[2]/td[2]/p[text()="B2|"]', output, 1
    end

    test 'should treat trailing pipe as an empty cell' do
      input = <<-EOS
|====
|A1 |
|B1 |B2
|C1 |C2
|====
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > tbody > tr', output, 3
      assert_xpath '/table/tbody/tr[1]/td', output, 2
      assert_xpath '/table/tbody/tr[1]/td[1]/p[text()="A1"]', output, 1
      assert_xpath '/table/tbody/tr[1]/td[2]/p', output, 0
      assert_xpath '/table/tbody/tr[2]/td[1]/p[text()="B1"]', output, 1
    end

    test 'should auto recover with warning if missing leading separator on first cell' do
      input = <<-EOS
|===
A | here| a | there
|===
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 4
      assert_css 'table > tbody > tr', output, 1
      assert_css 'table > tbody > tr > td', output, 4
      assert_xpath '/table/tbody/tr/td[1]/p[text()="A"]', output, 1
      assert_xpath '/table/tbody/tr/td[2]/p[text()="here"]', output, 1
      assert_xpath '/table/tbody/tr/td[3]/p[text()="a"]', output, 1
      assert_xpath '/table/tbody/tr/td[4]/p[text()="there"]', output, 1
    end

    test 'performs normal substitutions on cell content' do
      input = <<-EOS
:show_title: Cool new show
|===
|{show_title} |Coming soon...
|===
      EOS
      output = render_embedded_string input
      assert_xpath '//tbody/tr/td[1]/p[text()="Cool new show"]', output, 1
      assert_xpath %(//tbody/tr/td[2]/p[text()='Coming soon#{expand_entity 8230}#{expand_entity 8203}']), output, 1
    end

    test 'table and col width not assigned when autowidth option is specified' do
      input = <<-EOS
[options="autowidth"]
|=======
|A |B |C
|a |b |c
|1 |2 |3
|=======
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table[style*="width"]', output, 0
      assert_css 'table colgroup col', output, 3
      assert_css 'table colgroup col[width]', output, 0
    end

    test 'first row sets number of columns when not specified' do
      input = <<-EOS
|====
|first |second |third |fourth
|1 |2 |3
|4
|====
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 4
      assert_css 'table > tbody > tr', output, 2
      assert_css 'table > tbody > tr:nth-child(1) > td', output, 4
      assert_css 'table > tbody > tr:nth-child(2) > td', output, 4
    end

    test 'colspec attribute using asterisk syntax sets number of columns' do
      input = <<-EOS
[cols="3*"]
|===
|A |B |C |a |b |c |1 |2 |3
|===
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > tbody > tr', output, 3
    end

    test 'table with explicit column count can have multiple rows on a single line' do
      input = <<-EOS
[cols="3*"]
|===
|one |two
|1 |2 |a |b
|===
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 3
      assert_css 'table > tbody > tr', output, 2
    end

    test 'table with explicit deprecated colspec syntax can have multiple rows on a single line' do
      input = <<-EOS
[cols="3"]
|===
|one |two
|1 |2 |a |b
|===
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 3
      assert_css 'table > tbody > tr', output, 2
    end

    test 'columns are added for empty records in colspec attribute' do
      input = <<-EOS
[cols="<,"]
|===
|one |two
|1 |2 |a |b
|===
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > tbody > tr', output, 3
    end

    test 'cols attribute may include spaces' do
      input = <<-EOS
[cols=" 1, 1 "]
|===
|one |two |1 |2 |a |b
|===
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'col[style="width: 50%;"]', output, 2
      assert_css 'table > tbody > tr', output, 3
    end

    test 'blank cols attribute should be ignored' do
      input = <<-EOS
[cols=" "]
|===
|one |two
|1 |2 |a |b
|===
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'col[style="width: 50%;"]', output, 2
      assert_css 'table > tbody > tr', output, 3
    end

    test 'empty cols attribute should be ignored' do
      input = <<-EOS
[cols=""]
|===
|one |two
|1 |2 |a |b
|===
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'col[style="width: 50%;"]', output, 2
      assert_css 'table > tbody > tr', output, 3
    end

    test 'table with header and footer' do
      input = <<-EOS
[frame="topbot",options="header,footer"]
|===
|Item       |Quantity
|Item 1     |1
|Item 2     |2
|Item 3     |3
|Total      |6
|===
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > thead', output, 1
      assert_css 'table > thead > tr', output, 1
      assert_css 'table > thead > tr > th', output, 2
      assert_css 'table > tfoot', output, 1
      assert_css 'table > tfoot > tr', output, 1
      assert_css 'table > tfoot > tr > td', output, 2
      assert_css 'table > tbody', output, 1
      assert_css 'table > tbody > tr', output, 3
    end

    test 'table with header and footer docbook' do
      input = <<-EOS
.Table with header, body and footer
[frame="topbot",options="header,footer"]
|===
|Item       |Quantity
|Item 1     |1
|Item 2     |2
|Item 3     |3
|Total      |6
|===
      EOS
      output = render_embedded_string input, :backend => 'docbook'
      assert_css 'table', output, 1
      assert_css 'table[frame="topbot"]', output, 1
      assert_css 'table > title', output, 1
      assert_css 'table > tgroup', output, 1
      assert_css 'table > tgroup[cols="2"]', output, 1
      assert_css 'table > tgroup[cols="2"] > colspec', output, 2
      assert_css 'table > tgroup[cols="2"] > colspec[colwidth="50*"]', output, 2
      assert_css 'table > tgroup > thead', output, 1
      assert_css 'table > tgroup > thead > row', output, 1
      assert_css 'table > tgroup > thead > row > entry', output, 2
      assert_css 'table > tgroup > thead > row > entry > simpara', output, 0
      assert_css 'table > tgroup > tfoot', output, 1
      assert_css 'table > tgroup > tfoot > row', output, 1
      assert_css 'table > tgroup > tfoot > row > entry', output, 2
      assert_css 'table > tgroup > tfoot > row > entry > simpara', output, 2
      assert_css 'table > tgroup > tbody', output, 1
      assert_css 'table > tgroup > tbody > row', output, 3
      assert_css 'table > tgroup > tbody > row', output, 3
    end

    test 'table with implicit header row' do
      input = <<-EOS
|===
|Column 1 |Column 2

|Data A1
|Data B1

|Data A2
|Data B2
|===
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > thead', output, 1
      assert_css 'table > thead > tr', output, 1
      assert_css 'table > thead > tr > th', output, 2
      assert_css 'table > tbody', output, 1
      assert_css 'table > tbody > tr', output, 2
    end

    test 'no implicit header row if second line not blank' do
      input = <<-EOS
|===
|Column 1 |Column 2
|Data A1
|Data B1

|Data A2
|Data B2
|===
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > thead', output, 0
      assert_css 'table > tbody', output, 1
      assert_css 'table > tbody > tr', output, 3
    end

    test 'no implicit header row if first line blank' do
      input = <<-EOS
|===

|Column 1 |Column 2

|Data A1
|Data B1

|Data A2
|Data B2

|===
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > thead', output, 0
      assert_css 'table > tbody', output, 1
      assert_css 'table > tbody > tr', output, 3
    end

    test 'no implicit header row if options is specified' do
      input = <<-EOS
[options=""]
|===
|Column 1 |Column 2

|Data A1
|Data B1

|Data A2
|Data B2
|===
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > thead', output, 0
      assert_css 'table > tbody', output, 1
      assert_css 'table > tbody > tr', output, 3
    end

    test 'styles not applied to header cells' do
      input = <<-EOS
[cols="1h,1s,1e",options="header,footer"]
|====
|Name |Occupation| Website
|Octocat |Social coding| http://github.com
|Name |Occupation| Website
|====
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > thead > tr > th', output, 3
      assert_css 'table > thead > tr > th > *', output, 0

      assert_css 'table > tfoot > tr > th', output, 1
      assert_css 'table > tfoot > tr > td', output, 2
      assert_css 'table > tfoot > tr > td > p > strong', output, 1
      assert_css 'table > tfoot > tr > td > p > em', output, 1

      assert_css 'table > tbody > tr > th', output, 1
      assert_css 'table > tbody > tr > td', output, 2
      assert_css 'table > tbody > tr > td > p.header', output, 0
      assert_css 'table > tbody > tr > td > p > strong', output, 1
      assert_css 'table > tbody > tr > td > p > em > a', output, 1
    end

    test 'vertical table headers use th element instead of header class' do
      input = <<-EOS
[cols="1h,1s,1e"]
|====

|Name |Occupation| Website

|Octocat |Social coding| http://github.com

|Name |Occupation| Website

|====
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > tbody > tr > th', output, 3
      assert_css 'table > tbody > tr > td', output, 6
      assert_css 'table > tbody > tr .header', output, 0
      assert_css 'table > tbody > tr > td > p > strong', output, 3
      assert_css 'table > tbody > tr > td > p > em', output, 3
      assert_css 'table > tbody > tr > td > p > em > a', output, 1
    end

    test 'supports horizontal and vertical source data with blank lines and table header' do
      input = <<-EOS
.Horizontal and vertical source data
[width="80%",cols="3,^2,^2,10",options="header"]
|===
|Date |Duration |Avg HR |Notes

|22-Aug-08 |10:24 | 157 |
Worked out MSHR (max sustainable heart rate) by going hard
for this interval.

|22-Aug-08 |23:03 | 152 |
Back-to-back with previous interval.

|24-Aug-08 |40:00 | 145 |
Moderately hard interspersed with 3x 3min intervals (2 min
hard + 1 min really hard taking the HR up to 160).

I am getting in shape!

|===
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table[style*="width: 80%"]', output, 1
      assert_xpath '/table/caption[@class="title"][text()="Table 1. Horizontal and vertical source data"]', output, 1
      assert_css 'table > colgroup > col', output, 4
      assert_css 'table > colgroup > col:nth-child(1)[@style*="width: 17.647%"]', output, 1
      assert_css 'table > colgroup > col:nth-child(2)[@style*="width: 11.7647%"]', output, 1
      assert_css 'table > colgroup > col:nth-child(3)[@style*="width: 11.7647%"]', output, 1
      assert_css 'table > colgroup > col:nth-child(4)[@style*="width: 58.8236%"]', output, 1
      assert_css 'table > thead', output, 1
      assert_css 'table > thead > tr', output, 1
      assert_css 'table > thead > tr > th', output, 4
      assert_css 'table > tbody > tr', output, 3
      assert_css 'table > tbody > tr:nth-child(1) > td', output, 4
      assert_css 'table > tbody > tr:nth-child(2) > td', output, 4
      assert_css 'table > tbody > tr:nth-child(3) > td', output, 4
      assert_xpath "/table/tbody/tr[1]/td[4]/p[text()='Worked out MSHR (max sustainable heart rate) by going hard\nfor this interval.']", output, 1
      assert_css 'table > tbody > tr:nth-child(3) > td:nth-child(4) > p', output, 2
      assert_xpath '/table/tbody/tr[3]/td[4]/p[2][text()="I am getting in shape!"]', output, 1
    end

    test 'percentages as column widths' do
      input = <<-EOS
[cols="<.^10%,<90%"]
|===
|column A |column B
|===
      EOS

      output = render_embedded_string input
      assert_xpath '/table/colgroup/col', output, 2
      assert_xpath '(/table/colgroup/col)[1][@style="width: 10%;"]', output, 1
      assert_xpath '(/table/colgroup/col)[2][@style="width: 90%;"]', output, 1
    end

    test 'spans, alignments and styles' do
      input = <<-EOS
[cols="e,m,^,>s",width="25%"]
|===
|1 >s|2 |3 |4
^|5 2.2+^.^|6 .3+<.>m|7
^|8
d|9 2+>|10
|===
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col[style*="width: 25%"]', output, 4
      assert_css 'table > tbody > tr', output, 4
      assert_css 'table > tbody > tr > td', output, 10
      assert_css 'table > tbody > tr:nth-child(1) > td', output, 4
      assert_css 'table > tbody > tr:nth-child(2) > td', output, 3
      assert_css 'table > tbody > tr:nth-child(3) > td', output, 1
      assert_css 'table > tbody > tr:nth-child(4) > td', output, 2

      assert_css 'table > tbody > tr:nth-child(1) > td:nth-child(1).halign-left.valign-top p em', output, 1
      assert_css 'table > tbody > tr:nth-child(1) > td:nth-child(2).halign-right.valign-top p strong', output, 1
      assert_css 'table > tbody > tr:nth-child(1) > td:nth-child(3).halign-center.valign-top p', output, 1
      assert_css 'table > tbody > tr:nth-child(1) > td:nth-child(3).halign-center.valign-top p *', output, 0
      assert_css 'table > tbody > tr:nth-child(1) > td:nth-child(4).halign-right.valign-top p strong', output, 1

      assert_css 'table > tbody > tr:nth-child(2) > td:nth-child(1).halign-center.valign-top p em', output, 1
      assert_css 'table > tbody > tr:nth-child(2) > td:nth-child(2).halign-center.valign-middle[colspan="2"][rowspan="2"] p code', output, 1
      assert_css 'table > tbody > tr:nth-child(2) > td:nth-child(3).halign-left.valign-bottom[rowspan="3"] p code', output, 1

      assert_css 'table > tbody > tr:nth-child(3) > td:nth-child(1).halign-center.valign-top p em', output, 1

      assert_css 'table > tbody > tr:nth-child(4) > td:nth-child(1).halign-left.valign-top p', output, 1
      assert_css 'table > tbody > tr:nth-child(4) > td:nth-child(1).halign-left.valign-top p em', output, 0
      assert_css 'table > tbody > tr:nth-child(4) > td:nth-child(2).halign-right.valign-top[colspan="2"] p code', output, 1
    end

    test 'sets up columns correctly if first row has cell that spans columns' do
      input = <<-EOS
|===
2+^|AAA |CCC
|AAA |BBB |CCC
|AAA |BBB |CCC
|===
      EOS
      output = render_embedded_string input
      assert_css 'table > tbody > tr:nth-child(1) > td', output, 2
      assert_css 'table > tbody > tr:nth-child(1) > td:nth-child(1)[colspan="2"]', output, 1
      assert_css 'table > tbody > tr:nth-child(1) > td:nth-child(2):not([colspan])', output, 1
      assert_css 'table > tbody > tr:nth-child(2) > td:not([colspan])', output, 3
      assert_css 'table > tbody > tr:nth-child(3) > td:not([colspan])', output, 3
    end

    test 'supports repeating cells' do
      input = <<-EOS
|===
3*|A
|1 3*|2
|b |c
|===
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 3
      assert_css 'table > tbody > tr', output, 3
      assert_css 'table > tbody > tr:nth-child(1) > td', output, 3
      assert_css 'table > tbody > tr:nth-child(2) > td', output, 3
      assert_css 'table > tbody > tr:nth-child(3) > td', output, 3

      assert_xpath '/table/tbody/tr[1]/td[1]/p[text()="A"]', output, 1
      assert_xpath '/table/tbody/tr[1]/td[2]/p[text()="A"]', output, 1
      assert_xpath '/table/tbody/tr[1]/td[3]/p[text()="A"]', output, 1

      assert_xpath '/table/tbody/tr[2]/td[1]/p[text()="1"]', output, 1
      assert_xpath '/table/tbody/tr[2]/td[2]/p[text()="2"]', output, 1
      assert_xpath '/table/tbody/tr[2]/td[3]/p[text()="2"]', output, 1

      assert_xpath '/table/tbody/tr[3]/td[1]/p[text()="2"]', output, 1
      assert_xpath '/table/tbody/tr[3]/td[2]/p[text()="b"]', output, 1
      assert_xpath '/table/tbody/tr[3]/td[3]/p[text()="c"]', output, 1
    end

    test 'calculates colnames correctly when using implicit column count and single cell with colspan' do
      input = <<-EOS
|===
2+|Two Columns
|One Column |One Column
|===
      EOS

      output = render_embedded_string input, :backend => 'docbook'
      assert_xpath '//colspec', output, 2
      assert_xpath '(//colspec)[1][@colname="col_1"]', output, 1
      assert_xpath '(//colspec)[2][@colname="col_2"]', output, 1
      assert_xpath '//row', output, 2
      assert_xpath '(//row)[1]/entry', output, 1
      assert_xpath '(//row)[1]/entry[@namest="col_1"][@nameend="col_2"]', output, 1
    end

    test 'calculates colnames correctly when using implicit column count and cells with mixed colspans' do
      input = <<-EOS
|===
2+|Two Columns | One Column
|One Column |One Column |One Column
|===
      EOS

      output = render_embedded_string input, :backend => 'docbook'
      assert_xpath '//colspec', output, 3
      assert_xpath '(//colspec)[1][@colname="col_1"]', output, 1
      assert_xpath '(//colspec)[2][@colname="col_2"]', output, 1
      assert_xpath '(//colspec)[3][@colname="col_3"]', output, 1
      assert_xpath '//row', output, 2
      assert_xpath '(//row)[1]/entry', output, 2
      assert_xpath '(//row)[1]/entry[@namest="col_1"][@nameend="col_2"]', output, 1
      assert_xpath '(//row)[2]/entry[@namest]', output, 0
      assert_xpath '(//row)[2]/entry[@nameend]', output, 0
    end

    test 'assigns unique column names for table with implicit column count and colspans in first row' do
      input = <<-EOS
|====
|                 2+| Node 0          2+| Node 1

| Host processes    | Core 0 | Core 1   | Core 4 | Core 5
| Guest processes   | Core 2 | Core 3   | Core 6 | Core 7
|====
      EOS

      output = render_embedded_string input, :backend => 'docbook'
      assert_xpath '//colspec', output, 5
      (1..5).each do |n|
        assert_xpath %((//colspec)[#{n}][@colname="col_#{n}"]), output, 1
      end
      assert_xpath '(//row)[1]/entry', output, 3
      assert_xpath '((//row)[1]/entry)[1][@namest]', output, 0
      assert_xpath '((//row)[1]/entry)[1][@namend]', output, 0
      assert_xpath '((//row)[1]/entry)[2][@namest="col_2"][@nameend="col_3"]', output, 1
      assert_xpath '((//row)[1]/entry)[3][@namest="col_4"][@nameend="col_5"]', output, 1
    end

    test 'ignores cell with colspan that exceeds colspec' do
      input = <<-EOS
[cols="1,1"]
|===
3+|A
|B
a|C

more C
|===
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table *', output, 0
    end

    test 'paragraph, verse and literal content' do
      input = <<-EOS
[cols=",^v,^l",options="header"]
|===
|Paragraphs |Verse |Literal
3*|The discussion about what is good,
what is beautiful, what is noble,
what is pure, and what is true
could always go on.

Why is that important?
Why would I like to do that?

Because that's the only conversation worth having.

And whether it goes on or not after I die, I don't know.
But, I do know that it is the conversation I want to have while I am still alive.

Which means that to me the offer of certainty,
the offer of complete security,
the offer of an impermeable faith that can't give way
is an offer of something not worth having.

I want to live my life taking the risk all the time
that I don't know anything like enough yet...
that I haven't understood enough...
that I can't know enough...
that I am always hungrily operating on the margins
of a potentially great harvest of future knowledge and wisdom.

I wouldn't have it any other way.
|===
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 3
      assert_css 'table > thead', output, 1
      assert_css 'table > thead > tr', output, 1
      assert_css 'table > thead > tr > th', output, 3
      assert_css 'table > tbody', output, 1
      assert_css 'table > tbody > tr', output, 1
      assert_css 'table > tbody > tr > td', output, 3
      assert_css 'table > tbody > tr > td:nth-child(1).halign-left.valign-top > p.tableblock', output, 7
      assert_css 'table > tbody > tr > td:nth-child(2).halign-center.valign-top > div.verse', output, 1
      verse = xmlnodes_at_css 'table > tbody > tr > td:nth-child(2).halign-center.valign-top > div.verse', output, 1
      assert_equal 26, verse.text.lines.entries.size
      assert_css 'table > tbody > tr > td:nth-child(3).halign-center.valign-top > div.literal > pre', output, 1
      literal = xmlnodes_at_css 'table > tbody > tr > td:nth-child(3).halign-center.valign-top > div.literal > pre', output, 1
      assert_equal 26, literal.text.lines.entries.size
    end

    test 'basic asciidoc cell' do
      input = <<-EOS
|===
a|--
NOTE: content

content
--
|===
      EOS

      result = render_embedded_string input
      assert_css 'table.tableblock', result, 1
      assert_css 'table.tableblock td.tableblock', result, 1
      assert_css 'table.tableblock td.tableblock .openblock', result, 1
      assert_css 'table.tableblock td.tableblock .openblock .admonitionblock', result, 1
      assert_css 'table.tableblock td.tableblock .openblock .paragraph', result, 1
    end

    test 'doctype can be set in asciidoc table cell' do
      input = <<-EOS
|===
a|
:doctype: inline

content
|===
      EOS

      result = render_embedded_string input
      assert_css 'table.tableblock', result, 1
      assert_css 'table.tableblock .paragraph', result, 0
    end

    test 'compat mode can be activated in asciidoc table cell' do
      input = <<-EOS
|===
a|
:compat-mode:

'italic'
|===
      EOS

      result = render_embedded_string input
      assert_css 'table.tableblock td em', result, 1
    end

    test 'asciidoc content' do
      input = <<-EOS
[cols="1e,1,5a",frame="topbot",options="header"]
|===
|Name |Backends |Description

|badges |xhtml11, html5 |
Link badges ('XHTML 1.1' and 'CSS') in document footers.

NOTE: The path names of images, icons and scripts are relative path
names to the output document not the source document.

|[[X97]] docinfo, docinfo1, docinfo2 |All backends |
These three attributes control which document information
files will be included in the the header of the output file:

docinfo:: Include `<filename>-docinfo.<ext>`
docinfo1:: Include `docinfo.<ext>`
docinfo2:: Include `docinfo.<ext>` and `<filename>-docinfo.<ext>`

Where `<filename>` is the file name (sans extension) of the AsciiDoc
input file and `<ext>` is `.html` for HTML outputs or `.xml` for
DocBook outputs. If the input file is the standard input then the
output file name is used.
|===
      EOS
      doc = document_from_string input
      table = doc.blocks.first
      assert !table.nil?
      tbody = table.rows.body
      assert_equal 2, tbody.size
      body_cell_1_3 = tbody[0][2]
      assert !body_cell_1_3.inner_document.nil?
      assert body_cell_1_3.inner_document.nested?
      assert_equal doc, body_cell_1_3.inner_document.parent_document
      assert_equal doc.converter, body_cell_1_3.inner_document.converter
      output = doc.render

      assert_css 'table > tbody > tr', output, 2
      assert_css 'table > tbody > tr:nth-child(1) > td:nth-child(3) div.admonitionblock', output, 1
      assert_css 'table > tbody > tr:nth-child(2) > td:nth-child(3) div.dlist', output, 1
    end

    test 'preprocessor directive on first line of an AsciiDoc table cell should be processed' do
      input = <<-EOS
|===
a|include::fixtures/include-file.asciidoc[]
|===
      EOS

      output = render_embedded_string input, :safe => :safe, :base_dir => File.dirname(__FILE__)
      assert_match(/included content/, output)
    end

    test 'cross reference link in an AsciiDoc table cell should resolve to reference in main document' do
      input = <<-EOS
== Some

|===
a|See <<_more>>
|===

== More

content
      EOS

      result = render_string input
      assert_xpath '//a[@href="#_more"]', result, 1
      assert_xpath '//a[@href="#_more"][text()="More"]', result, 1
    end

    test 'footnotes should not be shared between an AsciiDoc table cell and the main document' do
      input = <<-EOS
|===
a|AsciiDoc footnote:[A lightweight markup language.]
|===
      EOS

      result = render_string input
      assert_css '#_footnote_1', result, 1
    end

    test 'callout numbers should be globally unique, including AsciiDoc table cells' do
      input = <<-EOS
= Document Title

== Section 1

|====
a|
[source, yaml]
----
key: value <1>
----
<1> First callout
|====

== Section 2

|====
a|
[source, yaml]
----
key: value <1>
----
<1> Second callout
|====

== Section 3

[source, yaml]
----
key: value <1>
----
<1> Third callout
      EOS

      result = render_string input, :backend => 'docbook'
      conums = xmlnodes_at_xpath '//co', result
      assert_equal 3, conums.size
      ['CO1-1', 'CO2-1', 'CO3-1'].each_with_index do |conum, idx|
        assert_equal conum, conums[idx].attribute('xml:id').value
      end
      callouts = xmlnodes_at_xpath '//callout', result
      assert_equal 3, callouts.size
      ['CO1-1', 'CO2-1', 'CO3-1'].each_with_index do |callout, idx|
        assert_equal callout, callouts[idx].attribute('arearefs').value
      end
    end

    test 'nested table' do
      input = <<-EOS
[cols="1,2a"]
|===
|Normal cell
|Cell with nested table
[cols="2,1"]
!===
!Nested table cell 1 !Nested table cell 2
!===
|===
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 2
      assert_css 'table table', output, 1
      assert_css 'table table', output, 1
      assert_css 'table > tbody > tr > td:nth-child(2) table', output, 1
      assert_css 'table > tbody > tr > td:nth-child(2) table > tbody > tr > td', output, 2
    end

    test 'toc from parent document should not be included in an AsciiDoc table cell' do
      input = <<-EOS
= Document Title
:toc:

== Section A

|===
a|AsciiDoc content
|===
      EOS

      output = render_string input
      assert_css '.toc', output, 1
      assert_css 'table .toc', output, 0
    end

    test 'should be able to enable toc in an AsciiDoc table cell' do
      input = <<-EOS
= Document Title

== Section A

|===
a|
= Subdocument Title
:toc:

== Subdocument Section A

content
|===
      EOS

      output = render_string input
      assert_css '.toc', output, 1
      assert_css 'table .toc', output, 1
    end

    test 'should be able to enable toc in both outer document and in an AsciiDoc table cell' do
      input = <<-EOS
= Document Title
:toc:

== Section A

|===
a|
= Subdocument Title
:toc: macro

[#table-cell-toc]
toc::[]

== Subdocument Section A

content
|===
      EOS

      output = render_string input
      assert_css '.toc', output, 2
      assert_css '#toc', output, 1
      assert_css 'table .toc', output, 1
      assert_css 'table #table-cell-toc', output, 1
    end

    test 'document in an AsciiDoc table cell should not see doctitle of parent' do
      input = <<-EOS
= Document Title

[cols="1a"]
|===
|AsciiDoc content
|===
      EOS

      output = render_string input
      assert_css 'table', output, 1
      assert_css 'table > tbody > tr > td', output, 1
      assert_css 'table > tbody > tr > td #preamble', output, 0
      assert_css 'table > tbody > tr > td .paragraph', output, 1
    end

    test 'cell background color' do
      input = <<-EOS
[cols="1e,1", options="header"]
|===
|{set:cellbgcolor:green}green
|{set:cellbgcolor!}
plain
|{set:cellbgcolor:red}red
|{set:cellbgcolor!}
plain
|===
      EOS

      output = render_embedded_string input
      assert_xpath '(/table/thead/tr/th)[1][@style="background-color: green;"]', output, 1
      assert_xpath '(/table/thead/tr/th)[2][@style="background-color: green;"]', output, 0
      assert_xpath '(/table/tbody/tr/td)[1][@style="background-color: red;"]', output, 1
      assert_xpath '(/table/tbody/tr/td)[2][@style="background-color: green;"]', output, 0
    end
  end

  context 'DSV' do

    test 'renders simple dsv table' do
      input = <<-EOS
[width="75%",format="dsv"]
|===
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/bin:/sbin/nologin
mysql:x:27:27:MySQL\\:Server:/var/lib/mysql:/bin/bash
gdm:x:42:42::/var/lib/gdm:/sbin/nologin
sshd:x:74:74:Privilege-separated SSH:/var/empty/sshd:/sbin/nologin
nobody:x:99:99:Nobody:/:/sbin/nologin
|===
      EOS
      doc = document_from_string input, :header_footer => false
      table = doc.blocks[0]
      assert 100, table.columns.map {|col| col.attributes['colpcwidth'] }.reduce(:+)
      output = doc.convert
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col[style*="width: 14.2857"]', output, 6
      assert_css 'table > colgroup > col:last-of-type[style*="width: 14.2858%"]', output, 1
      assert_css 'table > tbody > tr', output, 6
      assert_xpath '//tr[4]/td[5]/p/text()', output, 0
      assert_xpath '//tr[3]/td[5]/p[text()="MySQL:Server"]', output, 1
    end

    test 'dsv format shorthand' do
      input = <<-EOS
:===
a:b:c
1:2:3
:===
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 3
      assert_css 'table > tbody > tr', output, 2
      assert_css 'table > tbody > tr:nth-child(1) > td', output, 3
      assert_css 'table > tbody > tr:nth-child(2) > td', output, 3
    end

    test 'single cell in DSV table should only produce single row' do
      input = <<-EOS
:===
single cell
:===
      EOS

      output = render_embedded_string input
      assert_css 'table td', output, 1
    end

    test 'should treat trailing colon as an empty cell' do
      input = <<-EOS
:====
A1:
B1:B2
C1:C2
:====
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > tbody > tr', output, 3
      assert_xpath '/table/tbody/tr[1]/td', output, 2
      assert_xpath '/table/tbody/tr[1]/td[1]/p[text()="A1"]', output, 1
      assert_xpath '/table/tbody/tr[1]/td[2]/p', output, 0
      assert_xpath '/table/tbody/tr[2]/td[1]/p[text()="B1"]', output, 1
    end
  end

  context 'CSV' do

    test 'should treat trailing comma as an empty cell' do
      input = <<-EOS
,====
A1,
B1,B2
C1,C2
,====
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > tbody > tr', output, 3
      assert_xpath '/table/tbody/tr[1]/td', output, 2
      assert_xpath '/table/tbody/tr[1]/td[1]/p[text()="A1"]', output, 1
      assert_xpath '/table/tbody/tr[1]/td[2]/p', output, 0
      assert_xpath '/table/tbody/tr[2]/td[1]/p[text()="B1"]', output, 1
    end

    test 'mixed unquoted records and quoted records with escaped quotes, commas and wrapped lines' do
      input = <<-EOS
[format="csv",options="header"]
|===
Year,Make,Model,Description,Price
1997,Ford,E350,"ac, abs, moon",3000.00
1999,Chevy,"Venture ""Extended Edition""","",4900.00
1999,Chevy,"Venture ""Extended Edition, Very Large""",,5000.00
1996,Jeep,Grand Cherokee,"MUST SELL!
air, moon roof, loaded",4799.00
|===
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col[style*="width: 20%"]', output, 5
      assert_css 'table > thead > tr', output, 1
      assert_css 'table > tbody > tr', output, 4
      assert_xpath '((//tbody/tr)[1]/td)[4]/p[text()="ac, abs, moon"]', output, 1
      assert_xpath %(((//tbody/tr)[2]/td)[3]/p[text()='Venture "Extended Edition"']), output, 1
      assert_xpath '((//tbody/tr)[4]/td)[4]/p[text()="MUST SELL! air, moon roof, loaded"]', output, 1
    end

    test 'csv format shorthand' do
      input = <<-EOS
,===
a,b,c
1,2,3
,===
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 3
      assert_css 'table > tbody > tr', output, 2
      assert_css 'table > tbody > tr:nth-child(1) > td', output, 3
      assert_css 'table > tbody > tr:nth-child(2) > td', output, 3
    end

    test 'custom separator' do
      input = <<-EOS
[format="csv", separator=";"]
|===
a;b;c
1;2;3
|===
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 3
      assert_css 'table > tbody > tr', output, 2
      assert_css 'table > tbody > tr:nth-child(1) > td', output, 3
      assert_css 'table > tbody > tr:nth-child(2) > td', output, 3
    end

    test 'custom separator for an AsciiDoc table cell' do
      input = <<-EOS
[cols=2,separator=!]
|===
!Pipe output to vim
a!
----
asciidoctor -o - -s test.adoc | view -
----
|===
      EOS
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col', output, 2
      assert_css 'table > tbody > tr', output, 1
      assert_css 'table > tbody > tr:nth-child(1) > td', output, 2
      assert_css 'table > tbody > tr:nth-child(1) > td:nth-child(1) p', output, 1
      assert_css 'table > tbody > tr:nth-child(1) > td:nth-child(2) .listingblock', output, 1
    end

    test 'single cell in CSV table should only produce single row' do
      input = <<-EOS
,===
single cell
,===
      EOS

      output = render_embedded_string input
      assert_css 'table td', output, 1
    end

    test 'table with breakable db45' do
      input = <<-EOS
.Table with breakable
[options="breakable"]
|===
|Item       |Quantity
|Item 1     |1
|===
      EOS
      output = render_embedded_string input, :backend => 'docbook45'
      assert output.include?('<?dbfo keep-together="auto"?>')
    end

    test 'table with breakable db5' do
      input = <<-EOS
.Table with breakable
[options="breakable"]
|===
|Item       |Quantity
|Item 1     |1
|===
      EOS
      output = render_embedded_string input, :backend => 'docbook5'
      assert output.include?('<?dbfo keep-together="auto"?>')
    end

    test 'table with unbreakable db5' do
      input = <<-EOS
.Table with unbreakable
[options="unbreakable"]
|===
|Item       |Quantity
|Item 1     |1
|===
      EOS
      output = render_embedded_string input, :backend => 'docbook5'
      assert output.include?('<?dbfo keep-together="always"?>')
    end

    test 'table with unbreakable db45' do
      input = <<-EOS
.Table with unbreakable
[options="unbreakable"]
|===
|Item       |Quantity
|Item 1     |1
|===
      EOS
      output = render_embedded_string input, :backend => 'docbook45'
      assert output.include?('<?dbfo keep-together="always"?>')
    end
  end
end
