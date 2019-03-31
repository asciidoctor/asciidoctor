# encoding: utf-8
require 'spec_helper'
require 'cucumber/multiline_argument/data_table'

module Cucumber
  module MultilineArgument
    describe DataTable do
      before do
        @table = DataTable.from([
          %w{one four seven},
          %w{4444 55555 666666}
        ])
      end

      it "should have rows" do
        expect( @table.cells_rows[0].map{|cell| cell.value} ).to eq %w{one four seven}
      end

      it "should have columns" do
        expect( @table.columns[1].map{|cell| cell.value} ).to eq %w{four 55555}
      end

      it "should have same cell objects in rows and columns" do
        # 666666
        expect( @table.cells_rows[1][2] ).to equal(@table.columns[2][1])
      end

      it "should be convertible to an array of hashes" do
        expect( @table.hashes ).to eq [
          {'one' => '4444', 'four' => '55555', 'seven' => '666666'}
        ]
      end

      it "should accept symbols as keys for the hashes" do
        expect( @table.hashes.first[:one] ).to eq '4444'
      end

      it "should return the row values in order" do
        expect( @table.rows.first ).to eq %w{4444 55555 666666}
      end

      describe '#symbolic_hashes' do

        it 'should covert data table to an array of hashes with symbols as keys' do
          ast_table = Cucumber::Core::Ast::DataTable.new([['foo', 'Bar', 'Foo Bar'], %w{1 22 333}], nil)
          data_table = DataTable.new(ast_table)
          expect(data_table.symbolic_hashes).to eq([{:foo => '1', :bar => '22', :foo_bar => '333'}])
        end

        it 'should be able to be accessed multiple times' do
          @table.symbolic_hashes
          expect{@table.symbolic_hashes}.to_not raise_error
        end

      end

      describe '#map_column!' do
        it "should allow mapping columns" do
          @table.map_column!('one') { |v| v.to_i }
          expect( @table.hashes.first['one'] ).to eq 4444
        end

        it "applies the block once to each value" do
          headers = ['header']
          rows = ['value']
          table = DataTable.from [headers, rows]
          count = 0
          table.map_column!('header') { |value| count +=1 }
          table.rows
          expect( count ).to eq rows.size
        end

        it "should allow mapping columns and take a symbol as the column name" do
          @table.map_column!(:one) { |v| v.to_i }
          expect( @table.hashes.first['one'] ).to eq 4444
        end

        it "should allow mapping columns and modify the rows as well" do
          @table.map_column!(:one) { |v| v.to_i }
          expect( @table.rows.first ).to include(4444)
          expect( @table.rows.first ).to_not include('4444')
        end

        it "should pass silently if a mapped column does not exist in non-strict mode" do
          expect {
            @table.map_column!('two', false) { |v| v.to_i }
            @table.hashes
          }.not_to raise_error
        end

        it "should fail if a mapped column does not exist in strict mode" do
          expect {
            @table.map_column!('two', true) { |v| v.to_i }
            @table.hashes
          }.to raise_error('The column named "two" does not exist')
        end

        it "should return the table" do
          expect( (@table.map_column!(:one) { |v| v.to_i }) ).to eq @table
        end
      end

      describe '#map_column' do
        it "should allow mapping columns" do
          new_table = @table.map_column('one') { |v| v.to_i }
          expect( new_table.hashes.first['one'] ).to eq 4444
        end

        it "applies the block once to each value" do
          headers = ['header']
          rows = ['value']
          table = DataTable.from [headers, rows]
          count = 0
          new_table = table.map_column('header') { |value| count +=1 }
          new_table.rows
          expect( count ).to eq rows.size
        end

        it "should allow mapping columns and take a symbol as the column name" do
          new_table = @table.map_column(:one) { |v| v.to_i }
          expect( new_table.hashes.first['one'] ).to eq 4444
        end

        it "should allow mapping columns and modify the rows as well" do
          new_table = @table.map_column(:one) { |v| v.to_i }
          expect( new_table.rows.first ).to include(4444)
          expect( new_table.rows.first ).to_not include('4444')
        end

        it "should pass silently if a mapped column does not exist in non-strict mode" do
          expect {
            new_table = @table.map_column('two', false) { |v| v.to_i }
            new_table.hashes
          }.not_to raise_error
        end

        it "should fail if a mapped column does not exist in strict mode" do
          expect {
            new_table = @table.map_column('two', true) { |v| v.to_i }
            new_table.hashes
          }.to raise_error('The column named "two" does not exist')
        end

        it "should return a new table" do
          expect( (@table.map_column(:one) { |v| v.to_i }) ).to_not eq @table
        end
      end

      describe "#match" do
        before(:each) do
          @table = DataTable.from([
            %w{one four seven},
            %w{4444 55555 666666}
          ])
        end

        it "returns nil if headers do not match" do
          expect( @table.match('does,not,match') ).to be_nil
        end
        it "requires a table: prefix on match" do
          expect( @table.match('table:one,four,seven') ).to_not be_nil
        end
        it "does not match if no table: prefix on match" do
          expect( @table.match('one,four,seven') ).to be_nil
        end
      end

      describe "#transpose" do
        before(:each) do
          @table = DataTable.from([
            %w{one 1111},
            %w{two 22222}
          ])
        end

        it "should be convertible in to an array where each row is a hash" do
          expect( @table.transpose.hashes[0] ).to eq('one' => '1111', 'two' => '22222')
        end
      end

      describe "#rows_hash" do

        it "should return a hash of the rows" do
          table = DataTable.from([
            %w{one 1111},
            %w{two 22222}
          ])
          expect( table.rows_hash ).to eq( 'one' => '1111', 'two' => '22222' )
        end

        it "should fail if the table doesn't have two columns" do
          faulty_table = DataTable.from([
            %w{one 1111 abc},
            %w{two 22222 def}
          ])
          expect {
            faulty_table.rows_hash
          }.to raise_error('The table must have exactly 2 columns')
        end

        it "should support header and column mapping" do
          table = DataTable.from([
            %w{one 1111},
            %w{two 22222}
          ])
          t2 = table.map_headers({ 'two' => 'Two' }) { |header| header.upcase }.
                     map_column('two', false) { |val| val.to_i }
          expect( t2.rows_hash ).to eq( 'ONE' => '1111', 'Two' => 22222 )
        end
      end

      describe '#map_headers!' do
        let(:table) do
          DataTable.from([
          %w{HELLO WORLD},
          %w{4444 55555}
          ])
        end

        it "renames the columns to the specified values in the provided hash" do
          @table.map_headers!('one' => :three)
          expect( @table.hashes.first[:three] ).to eq '4444'
        end

        it "allows renaming columns using regexp" do
          @table.map_headers!(/one|uno/ => :three)
          expect( @table.hashes.first[:three] ).to eq '4444'
        end

        it "copies column mappings" do
          @table.map_column!('one') { |v| v.to_i }
          @table.map_headers!('one' => 'three')
          expect( @table.hashes.first['three'] ).to eq 4444
        end

        it "takes a block and operates on all the headers with it" do
          table.map_headers! do |header|
            header.downcase
          end
          expect( table.hashes.first.keys ).to match %w[hello world]
        end

        it "treats the mappings in the provided hash as overrides when used with a block" do
          table.map_headers!('WORLD' => 'foo') do |header|
            header.downcase
          end

          expect( table.hashes.first.keys ).to match %w[hello foo]
        end
      end

      describe '#map_headers' do
        let(:table) do
           DataTable.from([
          %w{HELLO WORLD},
          %w{4444 55555}
          ])
        end

        it "renames the columns to the specified values in the provided hash" do
          table2 = @table.map_headers('one' => :three)
          expect( table2.hashes.first[:three] ).to eq '4444'
        end

        it "allows renaming columns using regexp" do
          table2 = @table.map_headers(/one|uno/ => :three)
          expect( table2.hashes.first[:three] ).to eq '4444'
        end

        it "copies column mappings" do
          @table.map_column!('one') { |v| v.to_i }
          table2 = @table.map_headers('one' => 'three')
          expect( table2.hashes.first['three'] ).to eq 4444
        end

        it "takes a block and operates on all the headers with it" do
          table2 = table.map_headers do |header|
            header.downcase
          end

          expect( table2.hashes.first.keys ).to match %w[hello world]
        end

        it "treats the mappings in the provided hash as overrides when used with a block" do
          table2 = table.map_headers('WORLD' => 'foo') do |header|
            header.downcase
          end

          expect( table2.hashes.first.keys ).to match %w[hello foo]
        end
      end

      describe "diff!" do
        it "should detect a complex diff" do
          t1 = DataTable.from(%{
            | 1         | 22          | 333         | 4444         |
            | 55555     | 666666      | 7777777     | 88888888     |
            | 999999999 | 0000000000  | 01010101010 | 121212121212 |
            | 4000      | ABC         | DEF         | 50000        |
          })

          t2 = DataTable.from(%{
            | a     | 4444     | 1         |
            | bb    | 88888888 | 55555     |
            | ccc   | xxxxxxxx | 999999999 |
            | dddd  | 4000     | 300       |
            | e     | 50000    | 4000      |
          })
          expect { t1.diff!(t2) }.to raise_error
          expect( t1.to_s(:indent => 12, :color => false) ).to eq %{
            |     1         | (-) 22         | (-) 333         |     4444         | (+) a    |
            |     55555     | (-) 666666     | (-) 7777777     |     88888888     | (+) bb   |
            | (-) 999999999 | (-) 0000000000 | (-) 01010101010 | (-) 121212121212 | (+)      |
            | (+) 999999999 | (+)            | (+)             | (+) xxxxxxxx     | (+) ccc  |
            | (+) 300       | (+)            | (+)             | (+) 4000         | (+) dddd |
            |     4000      | (-) ABC        | (-) DEF         |     50000        | (+) e    |
          }
        end

        it "should not change table when diffed with identical" do
          t = DataTable.from(%{
            |a|b|c|
            |d|e|f|
            |g|h|i|
          })
          t.diff!(t.dup)
          expect( t.to_s(:indent => 12, :color => false) ).to eq %{
            |     a |     b |     c |
            |     d |     e |     f |
            |     g |     h |     i |
          }
        end

        context "in case of duplicate header values" do
          it "raises no error for two identical tables" do
            t = DataTable.from(%{
            |a|a|c|
            |d|e|f|
            |g|h|i|
                               })
            t.diff!(t.dup)
            expect( t.to_s(:indent => 12, :color => false) ).to eq %{
            |     a |     a |     c |
            |     d |     e |     f |
            |     g |     h |     i |
          }
          end

          it "detects a diff in one cell" do
            t1 = DataTable.from(%{
            |a|a|c|
            |d|e|f|
            |g|h|i|
                                })
            t2 = DataTable.from(%{
            |a|a|c|
            |d|oops|f|
            |g|h|i|
                                })
            expect{ t1.diff!(t2) }.to raise_error
            expect( t1.to_s(:indent => 12, :color => false) ).to eq %{
            |     a |     a    |     c |
            | (-) d | (-) e    | (-) f |
            | (+) d | (+) oops | (+) f |
            |     g |     h    |     i |
          }
          end

          it "detects missing columns" do
            t1 = DataTable.from(%{
            |a|a|b|c|
            |d|d|e|f|
            |g|g|h|i|
                                })
            t2 = DataTable.from(%{
            |a|b|c|
            |d|e|f|
            |g|h|i|
                                })
            expect{ t1.diff!(t2) }.to raise_error
            expect( t1.to_s(:indent => 12, :color => false) ).to eq %{
            |     a | (-) a |     b |     c |
            |     d | (-) d |     e |     f |
            |     g | (-) g |     h |     i |
          }
          end

          it "detects surplus columns" do
            t1 = DataTable.from(%{
            |a|b|c|
            |d|e|f|
            |g|h|i|
                                })
            t2 = DataTable.from(%{
            |a|b|a|c|
            |d|e|d|f|
            |g|h|g|i|
                                })
            expect{ t1.diff!(t2, :surplus_col => true) }.to raise_error
            expect( t1.to_s(:indent => 12, :color => false) ).to eq %{
            |     a |     b |     c | (+) a |
            |     d |     e |     f | (+) d |
            |     g |     h |     i | (+) g |
          }
          end
        end

        it "should inspect missing and surplus cells" do
          t1 = DataTable.from([
            ['name',  'male', 'lastname', 'swedish'],
            ['aslak', 'true', 'hellesøy', 'false']
          ])
          t2 = DataTable.from([
            ['name',  'male', 'lastname', 'swedish'],
            ['aslak', true,   'hellesøy', false]
          ])
          expect { t1.diff!(t2) }.to raise_error

          expect( t1.to_s(:indent => 12, :color => false) ).to eq %{
            |     name  |     male       |     lastname |     swedish     |
            | (-) aslak | (-) (i) "true" | (-) hellesøy | (-) (i) "false" |
            | (+) aslak | (+) (i) true   | (+) hellesøy | (+) (i) false   |
          }
        end

        it "should allow column mapping of target before diffing" do
          t1 = DataTable.from([
            ['name',  'male'],
            ['aslak', 'true']
          ])
          t1.map_column!('male') { |m| m == 'true' }
          t2 = DataTable.from([
            ['name',  'male'],
            ['aslak', true]
          ])
          t1.diff!(t2)
          expect( t1.to_s(:indent => 12, :color => false) ).to eq %{
            |     name  |     male |
            |     aslak |     true |
          }
        end

        it "should allow column mapping of argument before diffing" do
          t1 = DataTable.from([
            ['name',  'male'],
            ['aslak', true]
          ])
          t1.map_column!('male') {
            'true'
          }
          t2 = DataTable.from([
            ['name',  'male'],
            ['aslak', 'true']
          ])
          t2.diff!(t1)
          expect( t1.to_s(:indent => 12, :color => false) ).to eq %{
            |     name  |     male |
            |     aslak |     true |
          }
        end

        it "should allow header mapping before diffing" do
          t1 = DataTable.from([
            ['Name',  'Male'],
            ['aslak', 'true']
          ])
          t1.map_headers!('Name' => 'name', 'Male' => 'male')
          t1.map_column!('male') { |m| m == 'true' }
          t2 = DataTable.from([
            ['name',  'male'],
            ['aslak', true]
          ])
          t1.diff!(t2)
          expect( t1.to_s(:indent => 12, :color => false) ).to eq %{
            |     name  |     male |
            |     aslak |     true |
          }
        end

        it "should detect seemingly identical tables as different" do
          t1 = DataTable.from([
            ['X',  'Y'],
            ['2', '1']
          ])
          t2 = DataTable.from([
            ['X',  'Y'],
            [2, 1]
          ])
          expect { t1.diff!(t2) }.to raise_error
          expect( t1.to_s(:indent => 12, :color => false) ).to eq %{
            |     X       |     Y       |
            | (-) (i) "2" | (-) (i) "1" |
            | (+) (i) 2   | (+) (i) 1   |
          }
        end

        it "should not allow mappings that match more than 1 column" do
          t1 = DataTable.from([
            ['Cuke',  'Duke'],
            ['Foo', 'Bar']
          ])
          expect do
            t1.map_headers!(/uk/ => 'u')
            t1.hashes
          end.to raise_error(%{2 headers matched /uk/: ["Cuke", "Duke"]})
        end

        describe "raising" do
          before do
            @t = DataTable.from(%{
              | a | b |
              | c | d |
            })
            expect( @t ).not_to eq nil
          end

          it "should raise on missing rows" do
            t = DataTable.from(%{
              | a | b |
            })
            expect( lambda { @t.dup.diff!(t) } ).to raise_error
            expect { @t.dup.diff!(t, :missing_row => false) }.not_to raise_error
          end

          it "should not raise on surplus rows when surplus is at the end" do
            t = DataTable.from(%{
              | a | b |
              | c | d |
              | e | f |
            })
            expect { @t.dup.diff!(t) }.to raise_error
            expect { @t.dup.diff!(t, :surplus_row => false) }.not_to raise_error
          end

          it "should not raise on surplus rows when surplus is interleaved" do
            t1 = DataTable.from(%{
              | row_1 | row_2 |
              | four  | 4     |
            })
            t2 = DataTable.from(%{
              | row_1 | row_2 |
              | one   | 1     |
              | two   | 2     |
              | three | 3     |
              | four  | 4     |
              | five  | 5     |
            })
            expect { t1.dup.diff!(t2) }.to raise_error

            expect { t1.dup.diff!(t2, :surplus_row => false) }.not_to raise_error
          end

          it "should raise on missing columns" do
            t = DataTable.from(%{
              | a |
              | c |
            })
            expect { @t.dup.diff!(t) }.to raise_error
            expect { @t.dup.diff!(t, :missing_col => false) }.not_to raise_error
          end

          it "should not raise on surplus columns" do
            t = DataTable.from(%{
              | a | b | x |
              | c | d | y |
            })
            expect { @t.dup.diff!(t) }.not_to raise_error
            expect { @t.dup.diff!(t, :surplus_col => true) }.to raise_error
          end

          it "should not raise on misplaced columns" do
            t = DataTable.from(%{
              | b | a |
              | d | c |
            })
            expect { @t.dup.diff!(t) }.not_to raise_error
            expect { @t.dup.diff!(t, :misplaced_col => true) }.to raise_error
          end
        end

        it "can compare to an Array" do
          t = DataTable.from(%{
            | b | a |
            | d | c |
          })
          other = [ %w{b a}, %w{d c} ]

          expect { t.diff!(other) }.not_to raise_error
        end
      end

      describe "#from" do
        it "should allow Array of Hash" do
          t1 = DataTable.from([{'name' => 'aslak', 'male' => 'true'}])
          expect( t1.to_s(:indent => 12, :color => false) ).to eq %{
            |     male |     name  |
            |     true |     aslak |
          }
        end
      end
    end
  end
end
