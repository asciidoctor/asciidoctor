require 'strscan'

# Parser for ASCIIMath expressions.
#
# The syntax for ASCIIMath in EBNF style notation is
#
# expr = ( simp ( fraction | sub | super ) )+
# simp = constant | paren_expr | unary_expr | binary_expr | text
# fraction = '/' simp
# super = '^' simp
# sub =  '_' simp super?
# paren_expr = lparen expr rparen
# lparen = '(' | '[' | '{' | '(:' | '{:'
# rparen = ')' | ']' | '}' | ':)' | ':}'
# unary_expr = unary_op simp
# unary_op = 'sqrt' | 'text'
# binary_expr = binary_op simp simp
# binary_op = 'frac' | 'root' | 'stackrel'
# text = '"' [^"]* '"'
# constant = number | symbol | identifier
# number = '-'? [0-9]+ ( '.' [0-9]+ )?
# symbol = /* any string in the symbol table */
# identifier = [A-z]
#
# ASCIIMath is parsed left to right without any form of operator precedence.
# When parsing the 'constant' the parser will try to find the longest matching string in the symbol
# table starting at the current position of the parser. If no matching string can be found the
# character at the current position of the parser is interpreted as an identifier instead.
module AsciiMath
  # Internal: Splits an ASCIIMath expression into a sequence of tokens.
  # Each token is represented as a Hash containing the keys :value and :type.
  # The :value key is used to store the text associated with each token.
  # The :type key indicates the semantics of the token. The value for :type will be one
  # of the following symbols:
  #
  # - :identifier a symbolic name or a bit of text without any further semantics
  # - :text a bit of arbitrary text
  # - :number a number
  # - :operator a mathematical operator symbol
  # - :unary a unary operator (e.g., sqrt, text, ...)
  # - :font a unary font command (e.g., bb, cc, ...)
  # - :infix an infix operator (e.g, /, _, ^, ...)
  # - :binary a binary operator (e.g., frac, root, ...)
  # - :accent an accent character
  # - :eof indicates no more tokens are available
  #
  # Each token type may also have an :underover modifier. When present and set to true
  # sub- and superscript expressions associated with the token will be rendered as
  # under- and overscriptabove and below rather than as sub- or superscript.
  #
  # :accent tokens additionally have a :postion value which is set to either :over or :under.
  # This determines if the accent should be rendered over or under the expression to which
  # it applies.
  #
  class Tokenizer
    WHITESPACE = /^\s+/
    NUMBER = /-?[0-9]+(?:\.[0-9]+)?/
    TEXT = /"[^"]+"/

    # Public: Initializes an ASCIIMath tokenizer.
    #
    # string - The ASCIIMath expression to tokenize
    # symbols - The symbol table to use while tokenizing
    def initialize(string, symbols)
      @string = StringScanner.new(string)
      @symbols = symbols
      lookahead = @symbols.keys.map { |k| k.length }.max
      @symbol_regexp = /([^\s0-9]{1,#{lookahead}})/
      @push_back = nil
    end

    # Public: Read the next token from the ASCIIMath expression and move the tokenizer
    # ahead by one token.
    #
    # Returns the next token as a Hash
    def next_token
      if @push_back
        t = @push_back
        @push_back = nil
        return t
      end

      @string.scan(WHITESPACE)

      return {:value => nil, :type => :eof} if @string.eos?

      case @string.peek(1)
        when '"'
          read_text
        when '-', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'
          read_number() || read_symbol
        else
          read_symbol()
      end
    end

    # Public: Pushes the given token back to the tokenizer. A subsequent call to next_token
    # will return the given token rather than generating a new one. At most one
    # token can be pushed back.
    #
    # token - The token to push back
    def push_back(token)
      @push_back = token unless token[:type] == :eof
    end

    private

    # Private: Reads a text token from the input string
    #
    # Returns the text token or nil if a text token could not be matched at
    # the current position
    def read_text
      read_value(TEXT) do |text|
        {:value => text[1..-2], :type => :text}
      end
    end

    # Private: Reads a number token from the input string
    #
    # Returns the number token or nil if a number token could not be matched at
    # the current position
    def read_number
      read_value(NUMBER) do |number|
        {:value => number, :type => :number}
      end
    end

    if String.method_defined?(:bytesize)
      def bytesize(s)
        s.bytesize
      end
    else
      def bytesize(s)
        s.length
      end
    end


    # Private: Reads a symbol token from the input string. This method first creates
    # a String from the input String starting from the current position with a length
    # that matches that of the longest key in the symbol table. It then looks up that
    # substring in the symbol table. If the substring is present in the symbol table, the
    # associated value is returned and the position is moved ahead by the length of the
    # substring. Otherwise this method chops one character off the end of the substring
    # and repeats the symbol lookup. This continues until a single character is left.
    # If that character can still not be found in the symbol table, then an identifier
    # token is returned whose value is the remaining single character string.
    #
    # Returns the token that was read or nil if a token could not be matched at
    # the current position
    def read_symbol
      position = @string.pos
      read_value(@symbol_regexp) do |s|
        until s.length == 1 || @symbols.include?(s)
          s.chop!
        end
        @string.pos = position + bytesize(s)
        @symbols[s] || {:value => s, :type => :identifier}
      end
    end

    # Private: Reads a String from the input String that matches the given RegExp
    #
    # regexp - a RegExp that will be used to match the token
    # block  - if a block is provided the matched token will be passed to the block
    #
    # Returns the matched String or the value returned by the block if one was given
    def read_value(regexp)
      s = @string.scan(regexp)
      if s
        yield s
      else
        s
      end
    end

    if String.respond_to?(:byte_size)
      def byte_size(s)
        s.byte_size
      end
    end
  end

  class Parser
    SYMBOLS = {
        # Operation symbols
        '+' => {:value => '+', :type => :operator},
        '-' => {:value => '&#x2212;', :type => :operator},
        '*' => {:value => '&#x22C5;', :type => :operator},
        '**' => {:value => '&#x22C6;', :type => :operator},
        '//' => {:value => '/', :type => :operator},
        '\\\\' => {:value => '\\', :type => :operator},
        'xx' => {:value => '&#x00D7;', :type => :operator},
        '-:' => {:value => '&#x00F7;', :type => :operator},
        '@' => {:value => '&#x26AC;', :type => :operator},
        'o+' => {:value => '&#x2295;', :type => :operator},
        'ox' => {:value => '&#x2297;', :type => :operator},
        'o.' => {:value => '&#x2299;', :type => :operator},
        'sum' => {:value => '&#x2211;', :type => :operator, :underover => true},
        'prod' => {:value => '&#x220F;', :type => :operator, :underover => true},
        '^^' => {:value => '&#x2227;', :type => :operator},
        '^^^' => {:value => '&#x22C0;', :type => :operator, :underover => true},
        'vv' => {:value => '&#x2228;', :type => :operator},
        'vvv' => {:value => '&#x22C1;', :type => :operator, :underover => true},
        'nn' => {:value => '&#x2229;', :type => :operator},
        'nnn' => {:value => '&#x22C2;', :type => :operator, :underover => true},
        'uu' => {:value => '&#x222A;', :type => :operator},
        'uuu' => {:value => '&#x22C3;', :type => :operator, :underover => true},

        # Relation symbols
        '=' => {:value => '=', :type => :operator},
        '!=' => {:value => '&#x2260;', :type => :operator},
        ':=' => {:value => ':=', :type => :operator},
        '<' => {:value => '&#x003C;', :type => :operator},
        'lt' => {:value => '&#x003C;', :type => :operator},
        '>' => {:value => '&#x003E;', :type => :operator},
        'gt' => {:value => '&#x003E;', :type => :operator},
        '<=' => {:value => '&#x2264;', :type => :operator},
        'lt=' => {:value => '&#x2264;', :type => :operator},
        '>=' => {:value => '&#x2265;', :type => :operator},
        'geq' => {:value => '&#x2265;', :type => :operator},
        '-<' => {:value => '&#x227A;', :type => :operator},
        '-lt' => {:value => '&#x227A;', :type => :operator},
        '>-' => {:value => '&#x227B;', :type => :operator},
        '-<=' => {:value => '&#x2AAF;', :type => :operator},
        '>-=' => {:value => '&#x2AB0;', :type => :operator},
        'in' => {:value => '&#x2208;', :type => :operator},
        '!in' => {:value => '&#x2209;', :type => :operator},
        'sub' => {:value => '&#x2282;', :type => :operator},
        'sup' => {:value => '&#x2283;', :type => :operator},
        'sube' => {:value => '&#x2286;', :type => :operator},
        'supe' => {:value => '&#x2287;', :type => :operator},
        '-=' => {:value => '&#x2261;', :type => :operator},
        '~=' => {:value => '&#x2245;', :type => :operator},
        '~~' => {:value => '&#x2248;', :type => :operator},
        'prop' => {:value => '&#x221D;', :type => :operator},

        # Logical symbols
        'and' => {:value => 'and', :type => :text},
        'or' => {:value => 'or', :type => :text},
        'not' => {:value => '&#x00AC;', :type => :operator},
        '=>' => {:value => '&#x21D2;', :type => :operator},
        'if' => {:value => 'if', :type => :operator},
        '<=>' => {:value => '&#x21D4;', :type => :operator},
        'AA' => {:value => '&#x2200;', :type => :operator},
        'EE' => {:value => '&#x2203;', :type => :operator},
        '_|_' => {:value => '&#x22A5;', :type => :operator},
        'TT' => {:value => '&#x22A4;', :type => :operator},
        '|--' => {:value => '&#x22A2;', :type => :operator},
        '|==' => {:value => '&#x22A8;', :type => :operator},

        # Grouping brackets
        '(' => {:value => '(', :type => :lparen},
        ')' => {:value => ')', :type => :rparen},
        '[' => {:value => '[', :type => :lparen},
        ']' => {:value => ']', :type => :rparen},
        '{' => {:value => '{', :type => :lparen},
        '}' => {:value => '}', :type => :rparen},
        '|' => {:value => '|', :type => :lrparen},
        '||' => {:value => '||', :type => :lrparen},
        '(:' => {:value => '&#x2329;', :type => :lparen},
        ':)' => {:value => '&#x232A;', :type => :rparen},
        '<<' => {:value => '&#x2329;', :type => :lparen},
        '>>' => {:value => '&#x232A;', :type => :rparen},
        '{:' => {:value => nil, :type => :lparen},
        ':}' => {:value => nil, :type => :rparen},

        # Miscellaneous symbols
        'int' => {:value => '&#x222B;', :type => :operator},
        'dx' => {:value => 'dx', :type => :identifier},
        'dy' => {:value => 'dy', :type => :identifier},
        'dz' => {:value => 'dz', :type => :identifier},
        'dt' => {:value => 'dt', :type => :identifier},
        'oint' => {:value => '&#x222E;', :type => :operator},
        'del' => {:value => '&#x2202;', :type => :operator},
        'grad' => {:value => '&#x2207;', :type => :operator},
        '+-' => {:value => '&#x00B1;', :type => :operator},
        'O/' => {:value => '&#x2205;', :type => :operator},
        'oo' => {:value => '&#x221E;', :type => :operator},
        'aleph' => {:value => '&#x2135;', :type => :operator},
        '...' => {:value => '...', :type => :operator},
        ':.' => {:value => '&#x2234;', :type => :operator},
        '/_' => {:value => '&#x2220;', :type => :operator},
        '\\ ' => {:value => '&#x00A0;', :type => :operator},
        'quad' => {:value => '\u00A0\u00A0', :type => :operator},
        'qquad' => {:value => '\u00A0\u00A0\u00A0\u00A0', :type => :operator},
        'cdots' => {:value => '&#x22EF;', :type => :operator},
        'vdots' => {:value => '&#x22EE;', :type => :operator},
        'ddots' => {:value => '&#x22F1;', :type => :operator},
        'diamond' => {:value => '&#x22C4;', :type => :operator},
        'square' => {:value => '&#x25A1;', :type => :operator},
        '|__' => {:value => '&#x230A;', :type => :operator},
        '__|' => {:value => '&#x230B;', :type => :operator},
        '|~' => {:value => '&#x2308;', :type => :operator},
        '~|' => {:value => '&#x2309;', :type => :operator},
        'CC' => {:value => '&#x2102;', :type => :operator},
        'NN' => {:value => '&#x2115;', :type => :operator},
        'QQ' => {:value => '&#x211A;', :type => :operator},
        'RR' => {:value => '&#x211D;', :type => :operator},
        'ZZ' => {:value => '&#x2124;', :type => :operator},
        'f' => {:value => 'f', :type => :identifier},
        'g' => {:value => 'g', :type => :identifier},

        # Standard functions
        'lim' => {:value => 'lim', :type => :operator, :underover => true},
        'Lim' => {:value => 'Lim', :type => :operator, :underover => true},
        'sin' => {:value => 'sin', :type => :operator},
        'cos' => {:value => 'cos', :type => :operator},
        'tan' => {:value => 'tan', :type => :operator},
        'sinh' => {:value => 'sinh', :type => :operator},
        'cosh' => {:value => 'cosh', :type => :operator},
        'tanh' => {:value => 'tanh', :type => :operator},
        'cot' => {:value => 'cot', :type => :operator},
        'sec' => {:value => 'sec', :type => :operator},
        'csc' => {:value => 'csc', :type => :operator},
        'log' => {:value => 'log', :type => :operator},
        'ln' => {:value => 'ln', :type => :operator},
        'det' => {:value => 'det', :type => :operator},
        'dim' => {:value => 'dim', :type => :operator},
        'mod' => {:value => 'mod', :type => :operator},
        'gcd' => {:value => 'gcd', :type => :operator},
        'lcm' => {:value => 'lcm', :type => :operator},
        'lub' => {:value => 'lub', :type => :operator},
        'glb' => {:value => 'glb', :type => :operator},
        'min' => {:value => 'min', :type => :operator, :underover => true},
        'max' => {:value => 'max', :type => :operator, :underover => true},

        # Accents
        'hat' => {:value => '&#x005E;', :type => :accent, :position => :over},
        'bar' => {:value => '&#x00AF;', :type => :accent, :position => :over},
        'ul' => {:value => '_', :type => :accent, :position => :under},
        'vec' => {:value => '&#x2192;', :type => :accent, :position => :over},
        'dot' => {:value => '.', :type => :accent, :position => :over},
        'ddot' => {:value => '..', :type => :accent, :position => :over},

        # Arrows
        'uarr' => {:value => '&#x2191;', :type => :operator},
        'darr' => {:value => '&#x2193;', :type => :operator},
        'rarr' => {:value => '&#x2192;', :type => :operator},
        '->' => {:value => '&#x2192;', :type => :operator},
        '>->' => {:value => '&#x21A3;', :type => :operator},
        '->>' => {:value => '&#x21A0;', :type => :operator},
        '>->>' => {:value => '&#x2916;', :type => :operator},
        '|->' => {:value => '&#x21A6;', :type => :operator},
        'larr' => {:value => '&#x2190;', :type => :operator},
        'harr' => {:value => '&#x2194;', :type => :operator},
        'rArr' => {:value => '&#x21D2;', :type => :operator},
        'lArr' => {:value => '&#x21D0;', :type => :operator},
        'hArr' => {:value => '&#x21D4;', :type => :operator},

        # Other
        'sqrt' => {:value => :sqrt, :type => :unary},
        'text' => {:value => :text, :type => :unary},
        'bb' => {:value => :bold, :type => :font},
        'bbb' => {:value => :double_struck, :type => :font},
        'ii' => {:value => :italic, :type => :font},
        'bii' => {:value => :bold_italic, :type => :font},
        'cc' => {:value => :script, :type => :font},
        'bcc' => {:value => :bold_script, :type => :font},
        'tt' => {:value => :monospace, :type => :font},
        'fr' => {:value => :fraktur, :type => :font},
        'bfr' => {:value => :bold_fraktur, :type => :font},
        'sf' => {:value => :sans_serif, :type => :font},
        'bsf' => {:value => :bold_sans_serif, :type => :font},
        'sfi' => {:value => :sans_serif_italic, :type => :font},
        'sfbi' => {:value => :sans_serif_bold_italic, :type => :font},
        'frac' => {:value => :frac, :type => :binary},
        'root' => {:value => :root, :type => :binary},
        'stackrel' => {:value => :over, :type => :binary},
        '/' => {:value => :frac, :type => :infix},
        '_' => {:value => :sub, :type => :infix},
        '^' => {:value => :sup, :type => :infix},

        # Greek letters
        'alpha' => {:value => '&#x03b1;', :type => :identifier},
        'Alpha' => {:value => '&#x0391;', :type => :identifier},
        'beta' => {:value => '&#x03b2;', :type => :identifier},
        'Beta' => {:value => '&#x0392;', :type => :identifier},
        'gamma' => {:value => '&#x03b3;', :type => :identifier},
        'Gamma' => {:value => '&#x0393;', :type => :operator},
        'delta' => {:value => '&#x03b4;', :type => :identifier},
        'Delta' => {:value => '&#x0394;', :type => :operator},
        'epsilon' => {:value => '&#x03b5;', :type => :identifier},
        'Epsilon' => {:value => '&#x0395;', :type => :identifier},
        'varepsilon' => {:value => '&#x025b;', :type => :identifier},
        'zeta' => {:value => '&#x03b6;', :type => :identifier},
        'Zeta' => {:value => '&#x0396;', :type => :identifier},
        'eta' => {:value => '&#x03b7;', :type => :identifier},
        'Eta' => {:value => '&#x0397;', :type => :identifier},
        'theta' => {:value => '&#x03b8;', :type => :identifier},
        'Theta' => {:value => '&#x0398;', :type => :operator},
        'vartheta' => {:value => '&#x03d1;', :type => :identifier},
        'iota' => {:value => '&#x03b9;', :type => :identifier},
        'Iota' => {:value => '&#x0399;', :type => :identifier},
        'kappa' => {:value => '&#x03ba;', :type => :identifier},
        'Kappa' => {:value => '&#x039a;', :type => :identifier},
        'lambda' => {:value => '&#x03bb;', :type => :identifier},
        'Lambda' => {:value => '&#x039b;', :type => :operator},
        'mu' => {:value => '&#x03bc;', :type => :identifier},
        'Mu' => {:value => '&#x039c;', :type => :identifier},
        'nu' => {:value => '&#x03bd;', :type => :identifier},
        'Nu' => {:value => '&#x039d;', :type => :identifier},
        'xi' => {:value => '&#x03be;', :type => :identifier},
        'Xi' => {:value => '&#x039e;', :type => :operator},
        'omicron' => {:value => '&#x03bf;', :type => :identifier},
        'Omicron' => {:value => '&#x039f;', :type => :identifier},
        'pi' => {:value => '&#x03c0;', :type => :identifier},
        'Pi' => {:value => '&#x03a0;', :type => :operator},
        'rho' => {:value => '&#x03c1;', :type => :identifier},
        'Rho' => {:value => '&#x03a1;', :type => :identifier},
        'sigma' => {:value => '&#x03c3;', :type => :identifier},
        'Sigma' => {:value => '&#x03a3;', :type => :operator},
        'tau' => {:value => '&#x03c4;', :type => :identifier},
        'Tau' => {:value => '&#x03a4;', :type => :identifier},
        'upsilon' => {:value => '&#x03c5;', :type => :identifier},
        'Upsilon' => {:value => '&#x03a5;', :type => :identifier},
        'phi' => {:value => '&#x03c6;', :type => :identifier},
        'Phi' => {:value => '&#x03a6;', :type => :identifier},
        'varphi' => {:value => '&#x03d5;', :type => :identifier},
        'chi' => {:value => '\u03b3c7', :type => :identifier},
        'Chi' => {:value => '\u0393a7', :type => :identifier},
        'psi' => {:value => '&#x03c8;', :type => :identifier},
        'Psi' => {:value => '&#x03a8;', :type => :identifier},
        'omega' => {:value => '&#x03c9;', :type => :identifier},
        'Omega' => {:value => '&#x03a9;', :type => :operator},
    }

    def parse(input)
      Expression.new(
          input,
          parse_expression(Tokenizer.new(input, SYMBOLS), 0)
      )
    end

    private
    def parse_expression(tok, depth)
      e = []

      while (s1 = parse_simple_expression(tok, depth))
        t1 = tok.next_token

        if t1[:type] == :infix
          s2 = parse_simple_expression(tok, depth)
          t2 = tok.next_token
          if t1[:value] == :sub && t2[:value] == :sup
            s3 = parse_simple_expression(tok, depth)
            operator = s1[:underover] ? :underover : :subsup
            e << {:type => :ternary, :operator => operator, :s1 => s1, :s2 => s2, :s3 => s3}
          else
            operator = s1[:underover] ? (t1[:value] == :sub ? :under : :over) : t1[:value]
            e << {:type => :binary, :operator => operator, :s1 => s1, :s2 => s2}
            tok.push_back(t2)
            if (t2[:type] == :lrparen || t2[:type] == :rparen) && depth > 0
              break
            end
          end
        elsif t1[:type] == :eof
          e << s1
          break
        else
          e << s1
          tok.push_back(t1)
          if (t1[:type] == :lrparen || t1[:type] == :rparen) && depth > 0
            break
          end
        end
      end

      e
    end

    def parse_simple_expression(tok, depth)
      t1 = tok.next_token

      case t1[:type]
        when :lparen, :lrparen
          t2 = tok.next_token
          case t2[:type]
            when :rparen, :lrparen
              {:type => :paren, :e => nil, :lparen => t1[:value], :rparen => t2[:value]}
            else
              tok.push_back(t2)

              e = parse_expression(tok, depth + 1)

              t2 = tok.next_token
              case t2[:type]
                when :rparen, :lrparen
                  convert_to_matrix({:type => :paren, :e => e, :lparen => t1[:value], :rparen => t2[:value]})
                else
                  tok.push_back(t2)
                  {:type => :paren, :e => e, :lparen => t1[:value]}
              end
          end
        when :accent
          s = parse_simple_expression(tok, depth)
          {:type => :binary, :s1 => s, :s2 => {:type => :operator, :c => t1[:value]}, :operator => t1[:position]}
        when :unary, :font
          s = parse_simple_expression(tok, depth)
          {:type => t1[:type], :s => s, :operator => t1[:value]}
        when :binary
          s1 = parse_simple_expression(tok, depth)
          s2 = parse_simple_expression(tok, depth)
          {:type => :binary, :s1 => s1, :s2 => s2, :operator => t1[:value]}
        when :eof
          nil
        else
          {:type => t1[:type], :c => t1[:value], :underover => t1[:underover]}
      end
    end

    def convert_to_matrix(expression)
      return expression unless matrix? expression

      rows = expression[:e].select.with_index { |obj, i| i.even? }.map do |row|
        row[:e].select.with_index { |obj, i| i.even? }
      end

      {:type => :matrix, :rows => rows, :lparen => expression[:lparen], :rparen => expression[:rparen]}
    end

    def matrix?(expression)
      return false unless expression.is_a?(Hash) && expression[:type] == :paren

      rows, separators = expression[:e].partition.with_index { |obj, i| i.even? }

      rows.length > 1 &&
          rows.length > separators.length &&
          separators.all? { |item| item[:type] == :identifier && item[:c] == ',' } &&
          (rows.all? { |item| item[:type] == :paren && item[:lparen] == '(' && item[:rparen] == ')' } ||
              rows.all? { |item| item[:type] == :paren && item[:lparen] == '[' && item[:rparen] == ']' }) &&
          rows.all? { |item| item[:e].length == rows[0][:e].length } &&
          rows.all? { |item| matrix_cols?(item[:e]) }
    end

    def matrix_cols?(expression)
      return false unless expression.is_a?(Array)

      cols, separators = expression.partition.with_index { |obj, i| i.even? }

      cols.all? { |item| item[:type] != :identifier || item[:c] != ',' } &&
          separators.all? { |item| item[:type] == :identifier && item[:c] == ',' }
    end
  end

  class Expression
    def initialize(asciimath, parsed_expression)
      @asciimath = asciimath
      @parsed_expression = parsed_expression
    end

    def to_s
      @asciimath
    end
  end

  def self.parse(asciimath)
    Parser.new.parse(asciimath)
  end
end
