require 'test_helper'

context 'String' do

  test 'underscore should turn module into path and class name into words delimited by an underscore' do
    assert_equal 'asciidoctor/abstract_block', Asciidoctor::AbstractBlock.to_s.underscore
  end

  test 'underscore should convert hypens to underscores' do
    assert_equal 'one_on_one', 'one-on-one'.underscore
  end

  test 'underscore should convert camelcase word into words delimited by an underscore' do
    assert_equal 'big_voodoo_daddy', 'BigVoodooDaddy'.underscore
  end

  test 'ltrim should trim sequence of char from left of string' do
    assert_equal 'abc', '_abc'.ltrim('_')
    assert_equal 'abc', '___abc'.ltrim('_')
    assert_equal 'abc', 'abc'.ltrim('_')
  end

  test 'ltrim should not trim sequence of char from middle of string' do
    assert_equal 'a_b_c', 'a_b_c'.ltrim('_')
    assert_equal 'a___c', 'a___c'.ltrim('_')
    assert_equal 'a___c', '_a___c'.ltrim('_')
  end

  test 'rtrim should trim sequence of char from right of string' do
    assert_equal 'abc', 'abc_'.rtrim('_')
    assert_equal 'abc', 'abc___'.rtrim('_')
    assert_equal 'abc', 'abc'.rtrim('_')
  end

  test 'rtrim should not trim sequence of char from middle of string' do
    assert_equal 'a_b_c', 'a_b_c'.rtrim('_')
    assert_equal 'a___c', 'a___c'.rtrim('_')
    assert_equal 'a___c', 'a___c_'.rtrim('_')
  end

  test 'trim should trim sequence of char from boundaries of string' do
    assert_equal 'abc', '_abc_'.trim('_')
    assert_equal 'abc', '___abc___'.trim('_')
    assert_equal 'abc', '___abc_'.trim('_')
    assert_equal 'abc', '_abc___'.trim('_')
  end

  test 'trim should not trim sequence of char from middle of string' do
    assert_equal 'a_b_c', 'a_b_c'.trim('_')
    assert_equal 'a___c', 'a___c'.trim('_')
    assert_equal 'a___c', '_a___c_'.trim('_')
  end

  test 'nuke should remove first occurrence of matched pattern' do
    assert_equal 'ab_c', 'a_b_c'.nuke(/_/)
  end

  test 'gnuke should remove all occurrences of matched pattern' do
    assert_equal 'abc', 'a_b_c'.gnuke(/_/)
    assert_equal '-foo-bar', '#-?foo #-?bar'.gnuke(/[^\w-]/)
  end

end
