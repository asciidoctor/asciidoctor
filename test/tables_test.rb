require 'test_helper'

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
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table.tableblock.frame-all.grid-all[style*="width: 100%"]', output, 1
      assert_css 'table > colgroup > col[style*="width: 33%"]', output, 3
      assert_css 'table tr', output, 3
      assert_css 'table > tbody > tr', output, 3
      assert_css 'table td', output, 9
      assert_css 'table > tbody > tr > td.tableblock.halign-left.valign-top > p.tableblock', output, 9
      cells.each_with_index {|row, rowi|
        assert_css "table tr:nth-child(#{rowi + 1}) > td", output, row.size
        assert_css "table tr:nth-child(#{rowi + 1}) > td > p", output, row.size
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
      assert_xpath %(//tbody/tr/td[2]/p[text()='Coming soon#{[8230].pack('U*')}']), output, 1
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

    test 'colspec attribute sets number of columns' do
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

    test 'table with explicit deprecated syntax column count can have multiple rows on a single line' do
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

      assert_css 'table > tfoot > tr > td', output, 3
      assert_css 'table > tfoot > tr > td > p.header', output, 1
      assert_css 'table > tfoot > tr > td > p > strong', output, 1
      assert_css 'table > tfoot > tr > td > p > em', output, 1

      assert_css 'table > tbody > tr > td', output, 3
      assert_css 'table > tbody > tr > td > p.header', output, 1
      assert_css 'table > tbody > tr > td > p > strong', output, 1
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
      assert_css 'table > colgroup > col:nth-child(1)[@style*="width: 17%"]', output, 1
      assert_css 'table > colgroup > col:nth-child(2)[@style*="width: 11%"]', output, 1
      assert_css 'table > colgroup > col:nth-child(3)[@style*="width: 11%"]', output, 1
      assert_css 'table > colgroup > col:nth-child(4)[@style*="width: 58%"]', output, 1
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
      
      assert_css 'table tr:nth-child(1) > td:nth-child(1).halign-left.valign-top p em', output, 1
      assert_css 'table tr:nth-child(1) > td:nth-child(2).halign-right.valign-top p strong', output, 1
      assert_css 'table tr:nth-child(1) > td:nth-child(3).halign-center.valign-top p', output, 1
      assert_css 'table tr:nth-child(1) > td:nth-child(3).halign-center.valign-top p *', output, 0
      assert_css 'table tr:nth-child(1) > td:nth-child(4).halign-right.valign-top p strong', output, 1

      assert_css 'table tr:nth-child(2) > td:nth-child(1).halign-center.valign-top p em', output, 1
      assert_css 'table tr:nth-child(2) > td:nth-child(2).halign-center.valign-middle[colspan="2"][rowspan="2"] p tt', output, 1
      assert_css 'table tr:nth-child(2) > td:nth-child(3).halign-left.valign-bottom[rowspan="3"] p tt', output, 1

      assert_css 'table tr:nth-child(3) > td:nth-child(1).halign-center.valign-top p em', output, 1

      assert_css 'table tr:nth-child(4) > td:nth-child(1).halign-left.valign-top p', output, 1
      assert_css 'table tr:nth-child(4) > td:nth-child(1).halign-left.valign-top p em', output, 0
      assert_css 'table tr:nth-child(4) > td:nth-child(2).halign-right.valign-top[colspan="2"] p tt', output, 1
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
      assert_equal doc.renderer, body_cell_1_3.inner_document.renderer
      output = doc.render

      assert_css 'table > tbody > tr', output, 2
      assert_css 'table > tbody > tr:nth-child(1) > td:nth-child(3) div.admonitionblock', output, 1
      assert_css 'table > tbody > tr:nth-child(2) > td:nth-child(3) div.dlist', output, 1
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
      output = render_embedded_string input
      assert_css 'table', output, 1
      assert_css 'table > colgroup > col[style*="width: 14%"]', output, 7
      assert_css 'table > tbody > tr', output, 6
      assert_xpath '//tr[4]/td[5]/p/text()', output, 0
      assert_xpath '//tr[3]/td[5]/p[text()="MySQL:Server"]', output, 1
    end
  end

  context 'CSV' do

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
  end
end
