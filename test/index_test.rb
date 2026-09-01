# frozen_string_literal: true

require_relative 'test_helper'

context 'index catalog' do
  test 'stores sorted nested terms and all destinations' do
    index = Asciidoctor::IndexCatalog.new
    index.store_term ['zebra'], { anchor: 'zebra-1' }
    index.store_term %w(Animals Cats Tiger), { anchor: 'tiger-1' }
    index.store_term %w(Animals Cats Tiger), { anchor: 'tiger-2' }
    index.store_term ['@home'], { anchor: 'home-1' }

    assert_equal ['@', 'A', 'Z'], index.categories.map(&:name)
    animals = index.categories[1].terms[0]
    assert_equal 'Animals', animals.name
    assert_equal 'Cats', animals.subterms[0].name
    tiger = animals.subterms[0].subterms[0]
    assert_equal %w(tiger-1 tiger-2), (tiger.dests.map {|dest| dest[:anchor] })
  end

  test 'sorts terms case insensitively with uppercase first' do
    index = Asciidoctor::IndexCatalog.new
    %w(beta alpha Alpha).each {|name| index.store_term [name] }

    assert_equal %w(Alpha alpha beta), index.categories.flat_map(&:terms).map(&:name)
  end

  test 'resolves see and see-also associations and retains unresolved associations' do
    index = Asciidoctor::IndexCatalog.new
    flash = index.store_term ['Flash'], nil, see: 'HTML 5'
    html = index.store_term ['HTML 5'], nil, see_also: %w(CSS SVG)
    css = index.store_term ['CSS']

    index.link_associations

    assert_same html, flash.see
    assert_same css, html.see_also[0]
    assert_instance_of Asciidoctor::UnresolvedIndexTerm, html.see_also[1]
    assert_equal 'SVG', html.see_also[1].name
  end

  test 'uses plain formatted text for sorting and association lookup' do
    index = Asciidoctor::IndexCatalog.new
    formatted = index.store_term ['<strong>Tigers</strong>']
    reference = index.store_term ['Cats'], nil, see: 'Tigers'

    index.link_associations

    assert_equal 'T', index.categories.last.name
    assert_equal 'Tigers', formatted.sort_key
    assert_same formatted, reference.see
  end
end

context 'HTML index' do
  test 'does not add occurrence anchors without an index section' do
    output = Asciidoctor.convert 'A ((visible)) and (((concealed))) term.', standalone: false

    assert_equal %(<div class="paragraph">\n<p>A visible and  term.</p>\n</div>), output
  end

  test 'renders formal index term macros and associations' do
    output = convert_string_to_embedded <<~'EOS'
    = Felines
    :doctype: book

    == Cats

    indexterm2:[Tiger]
    indexterm:[Animals,Cats,Tiger]
    indexterm2:[Flash,see=HTML 5]
    indexterm2:[HTML 5,see-also=CSS]
    indexterm2:[CSS]

    [index]
    == Index
    EOS

    assert_css 'span.indexterm', output, 5
    assert_css 'li.index-entry li.index-entry li.index-entry', output, 1
    assert_xpath '//li[starts-with(., "Flash, see HTML 5")]/a[.="HTML 5"]', output, 1
    assert_xpath '//li[starts-with(., "HTML 5, Cats; see also CSS")]/a[.="CSS"]', output, 1
  end

  test 'does not catalog escaped or empty index term macros' do
    doc = document_from_string <<~'EOS', standalone: false
    \indexterm2:[visible] \indexterm:[concealed] indexterm:[ ]

    [index]
    == Index
    EOS

    output = doc.convert

    assert_include 'indexterm2:[visible] indexterm:[concealed]', output
    assert_empty doc.catalog[:indexterms]
    assert_css 'span.indexterm', output, 0
    refute_include 'index-category', output
  end

  test 'uses the document title for preamble terms and leaves unresolved associations unlinked' do
    output = convert_string_to_embedded <<~'EOS'
    = Web
    :doctype: book

    ((Preamble)) and ((Flash >> Missing)).

    [index]
    == Index
    EOS

    assert_xpath '//li[starts-with(., "Preamble, Web")]/a[.="Web"]', output, 1
    assert_xpath '//li[starts-with(., "Flash, see Missing")]/a', output, 0
  end

  test 'renders visible, concealed, nested, and repeated terms with occurrence links' do
    doc = document_from_string <<~'EOS', standalone: false
    = Felines
    :doctype: book

    == Cats

    A ((tiger)) and another ((tiger)).
    (((Animals, Cats, Tiger)))

    [index]
    == Index

    Index introduction.
    EOS

    output = doc.convert

    assert_css 'span.indexterm', output, 3
    assert_css 'div.index-category', output, 2
    assert_css 'div.index-category li.index-entry li.index-entry li.index-entry', output, 1
    assert_css 'li#__indextermdef-1 a[href="#__indexterm-1"]', output, 1
    assert_css 'li#__indextermdef-1 a[href="#__indexterm-2"]', output, 1
    assert_include 'Index introduction.', output
  end

  test 'renders see and see-also links' do
    output = convert_string_to_embedded <<~'EOS'
    = Web
    :doctype: book

    == Formats

    ((Flash >> HTML 5)) ((HTML 5 &> CSS)) ((CSS))

    [index]
    == Index
    EOS

    assert_xpath '//li[starts-with(., "Flash, see HTML 5")]/a[.="HTML 5"]', output, 1
    assert_xpath '//li[starts-with(., "HTML 5, Formats; see also CSS")]/a[.="CSS"]', output, 1
  end

  test 'preserves formatting and XML-sensitive characters in index terms' do
    output = convert_string_to_embedded <<~'EOS'
    = Felines
    :doctype: book

    == Cats

    ((*Tigers*)) and ((Cats & kittens)).

    [index]
    == Index
    EOS

    assert_xpath '//li[@class="index-entry"]/strong[.="Tigers"]', output, 1
    assert_xpath '//li[starts-with(., "Cats & kittens")]', output, 1
  end

  test 'uses a span destination when an index term is inside a link' do
    output = convert_string_to_embedded <<~'EOS'
    = Felines
    :doctype: book

    == Cats

    https://example.org[((Tigers))]

    [index]
    == Index
    EOS

    assert_css 'a > span.indexterm', output, 1
    assert_css 'a a', output, 0
  end

  test 'links an index term in a section title to the section' do
    output = convert_string_to_embedded <<~'EOS'
    = Felines
    :doctype: book

    == ((Cats))

    [index]
    == Index
    EOS

    assert_css 'li.index-entry a[href="#_cats"]', output, 1
  end

  test 'only includes terms before the index section' do
    output = convert_string_to_embedded <<~'EOS'
    = Terms
    :doctype: book

    == Before

    ((Before))

    [index]
    == Index

    == After

    ((After))
    EOS

    assert_xpath '//li[starts-with(., "Before,")]', output, 1
    assert_xpath '//li[starts-with(., "After,")]', output, 0
  end

  test 'produces the same index when a document is converted twice' do
    doc = document_from_string <<~'EOS', standalone: false
    = Felines
    :doctype: book

    == Cats

    ((Tiger)) and ((Tiger)).

    [index]
    == Index
    EOS

    first = doc.convert
    second = doc.convert
    tiger = doc.catalog[:indexterms].find_primary_term 'Tiger'

    assert_equal first, second
    assert_equal 2, tiger.dests.size
  end

  test 'preserves authored content when the index is empty' do
    output = convert_string_to_embedded <<~'EOS'
    = Felines
    :doctype: book

    [index]
    == Index

    No entries.
    EOS

    assert_include 'No entries.', output
    refute_include 'index-category', output
  end
end
