require 'spec_helper'
require 'singleton'

describe Docile do

  describe '.dsl_eval' do

    context 'when DSL context object is an Array' do
      let(:array) { [] }
      let!(:result) { execute_dsl_against_array }

      def execute_dsl_against_array
        Docile.dsl_eval(array) do
          push 1
          push 2
          pop
          push 3
        end
      end

      it 'executes the block against the DSL context object' do
        expect(array).to eq([1, 3])
      end

      it 'returns the DSL object after executing block against it' do
        expect(result).to eq(array)
      end

      it "doesn't proxy #__id__" do
        Docile.dsl_eval(array) { expect(__id__).not_to eq(array.__id__) }
      end

      it "raises NoMethodError if the DSL object doesn't implement the method" do
        expect { Docile.dsl_eval(array) { no_such_method } }.to raise_error(NoMethodError)
      end
    end

    Pizza = Struct.new(:cheese, :pepperoni, :bacon, :sauce)

    class PizzaBuilder
      def cheese(v=true);    @cheese    = v; end
      def pepperoni(v=true); @pepperoni = v; end
      def bacon(v=true);     @bacon     = v; end
      def sauce(v=nil);      @sauce     = v; end
      def build
        Pizza.new(!!@cheese, !!@pepperoni, !!@bacon, @sauce)
      end
    end

    context 'when DSL context object is a Builder pattern' do
      let(:builder) { PizzaBuilder.new }
      let(:result) { execute_dsl_against_builder_and_call_build }

      def execute_dsl_against_builder_and_call_build
        @sauce = :extra
        Docile.dsl_eval(builder) do
          bacon
          cheese
          sauce @sauce
        end.build
      end

      it 'returns correctly built object' do
        expect(result).to eq(Pizza.new(true, false, true, :extra))
      end
    end

    class InnerDSL
      def initialize; @b = 'b'; end
      attr_accessor :b
    end

    class OuterDSL
      def initialize; @a = 'a'; end
      attr_accessor :a

      def inner(&block)
        Docile.dsl_eval(InnerDSL.new, &block)
      end

      def inner_with_params(param, &block)
        Docile.dsl_eval(InnerDSL.new, param, :foo, &block)
      end
    end

    def outer(&block)
      Docile.dsl_eval(OuterDSL.new, &block)
    end

    context 'when given parameters for the DSL block' do
      def parameterized(*args, &block)
        Docile.dsl_eval(OuterDSL.new, *args, &block)
      end

      it 'passes parameters to the block' do
        parameterized(1,2,3) do |x,y,z|
          expect(x).to eq(1)
          expect(y).to eq(2)
          expect(z).to eq(3)
        end
      end

      it 'finds parameters before methods' do
        parameterized(1) { |a| expect(a).to eq(1) }
      end

      it 'find outer dsl parameters in inner dsl scope' do
        parameterized(1,2,3) do |a,b,c|
          inner_with_params(c) do |d,e|
            expect(a).to eq(1)
            expect(b).to eq(2)
            expect(c).to eq(3)
            expect(d).to eq(c)
            expect(e).to eq(:foo)
          end
        end
      end
    end

    class DSLWithNoMethod
      def initialize(b); @b = b; end
      attr_accessor :b
      def push_element
        @b.push 1
      end
    end

    context 'when DSL have NoMethod error inside' do
      it 'raise error from nil' do
        Docile.dsl_eval(DSLWithNoMethod.new(nil)) do
          expect { push_element }.to raise_error(NoMethodError, /undefined method `push' (for|on) nil:NilClass/)
        end
      end
    end

    context 'when DSL blocks are nested' do

      context 'method lookup' do
        it 'finds method of outer dsl in outer dsl scope' do
          outer { expect(a).to eq('a') }
        end

        it 'finds method of inner dsl in inner dsl scope' do
          outer { inner { expect(b).to eq('b') } }
        end

        it 'finds method of outer dsl in inner dsl scope' do
          outer { inner { expect(a).to eq('a') } }
        end

        it "finds method of block's context in outer dsl scope" do
          def c; 'c'; end
          outer { expect(c).to eq('c') }
        end

        it "finds method of block's context in inner dsl scope" do
          def c; 'c'; end
          outer { inner { expect(c).to eq('c') } }
        end

        it 'finds method of outer dsl in preference to block context' do
          def a; 'not a'; end
          outer { expect(a).to eq('a') }
          outer { inner { expect(a).to eq('a') } }
        end
      end

      context 'local variable lookup' do
        it 'finds local variable from block context in outer dsl scope' do
          foo = 'foo'
          outer { expect(foo).to eq('foo') }
        end

        it 'finds local variable from block definition in inner dsl scope' do
          bar = 'bar'
          outer { inner { expect(bar).to eq('bar') } }
        end
      end

      context 'instance variable lookup' do
        it 'finds instance variable from block definition in outer dsl scope' do
          @iv1 = 'iv1'; outer { expect(@iv1).to eq('iv1') }
        end

        it "proxies instance variable assignments in block in outer dsl scope back into block's context" do
          @iv1 = 'foo'; outer { @iv1 = 'bar' }; expect(@iv1).to eq('bar')
        end

        it 'finds instance variable from block definition in inner dsl scope' do
          @iv2 = 'iv2'; outer { inner { expect(@iv2).to eq('iv2') } }
        end

        it "proxies instance variable assignments in block in inner dsl scope back into block's context" do
          @iv2 = 'foo'; outer { inner { @iv2 = 'bar' } }; expect(@iv2).to eq('bar')
        end
      end

    end

    context 'when DSL context object is a Dispatch pattern' do
      class DispatchScope
        def params
          { :a => 1, :b => 2, :c => 3 }
        end
      end

      class MessageDispatch
        include Singleton

        def initialize
          @responders = {}
        end

        def add_responder path, &block
          @responders[path] = block
        end

        def dispatch path, request
          Docile.dsl_eval(DispatchScope.new, request, &@responders[path])
        end
      end

      def respond(path, &block)
        MessageDispatch.instance.add_responder(path, &block)
      end

      def send_request(path, request)
        MessageDispatch.instance.dispatch(path, request)
      end

      it 'dispatches correctly' do
        @first = @second = nil

        respond '/path' do |request|
          @first = request
        end

        respond '/new_bike' do |bike|
          @second = "Got a new #{bike}"
        end

        def x(y) ; "Got a #{y}"; end
        respond '/third' do |third|
          expect(x(third)).to eq('Got a third thing')
        end

        fourth = nil
        respond '/params' do |arg|
          fourth = params[arg]
        end

        send_request '/path', 1
        send_request '/new_bike', 'ten speed'
        send_request '/third', 'third thing'
        send_request '/params', :b

        expect(@first).to eq(1)
        expect(@second).to eq('Got a new ten speed')
        expect(fourth).to eq(2)
      end

    end

  end

  describe '.dsl_eval_immutable' do

    context 'when DSL context object is a frozen String' do
      let(:original) { "I'm immutable!".freeze }
      let!(:result) { execute_non_mutating_dsl_against_string }

      def execute_non_mutating_dsl_against_string
        Docile.dsl_eval_immutable(original) do
          reverse
          upcase
        end
      end

      it "doesn't modify the original string" do
        expect(original).to eq("I'm immutable!")
      end

      it 'chains the commands in the block against the DSL context object' do
        expect(result).to eq("!ELBATUMMI M'I")
      end
    end

    context 'when DSL context object is a number' do
      let(:original) { 84.5 }
      let!(:result) { execute_non_mutating_dsl_against_number }

      def execute_non_mutating_dsl_against_number
        Docile.dsl_eval_immutable(original) do
          fdiv(2)
          floor
        end
      end

      it 'chains the commands in the block against the DSL context object' do
        expect(result).to eq(42)
      end
    end
  end

end

describe Docile::FallbackContextProxy do

  describe '#instance_variables' do
    subject { create_fcp_and_set_one_instance_variable.instance_variables }
    let(:expected_type_of_names) { type_of_ivar_names_on_this_ruby }
    let(:actual_type_of_names) { subject.first.class }
    let(:excluded) { Docile::FallbackContextProxy::NON_PROXIED_INSTANCE_VARIABLES }

    def create_fcp_and_set_one_instance_variable
      fcp = Docile::FallbackContextProxy.new(nil, nil)
      fcp.instance_variable_set(:@foo, 'foo')
      fcp
    end

    def type_of_ivar_names_on_this_ruby
      @a = 1
      instance_variables.first.class
    end

    it 'returns proxied instance variables' do
      expect(subject.map(&:to_sym)).to include(:@foo)
    end

    it "doesn't return non-proxied instance variables" do
      expect(subject.map(&:to_sym)).not_to include(*excluded)
    end

    it 'preserves the type (String or Symbol) of names on this ruby version' do
      expect(actual_type_of_names).to eq(expected_type_of_names)
    end
  end

end
