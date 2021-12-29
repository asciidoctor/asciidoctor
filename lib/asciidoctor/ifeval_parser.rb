module Asciidoctor


# The recursive descent parser for asciidoctor-pdf's ifeval
#
# EBNF expression LL(*):
#   expr := disjunction
#   disjunction := conjunction ('or' conjunction)*
#   conjunction := inversion ('and' inversion)*
#   inversion := 'not' inversion
#              | comparison
#
#   comparison := term "==" term
#               | term "!=" term
#               | term ">" term
#               | term "<" term
#               | term "<=" term
#               | term ">=" term
#   term := literal
#       | '(' expr ')'
#
# reference:
#   https://docs.python.org/3/reference/grammar.html

class IfevalParser
  include Logging

  @str = ""
  @pos = 0
  @next_pos = 0
  @document
  
  def initialize doc
    @str = ""
    @pos = 0
    @next_pos = 0
    @document = doc
  end

  def peek_token
    @next_pos = @pos
    str = @str[@pos..-1]
    if str =~ /^\s*\d+/ ||                         # for number
       str =~ /^\s*[+\-*\/()]/ ||            # for operator
       str =~ /^\s*(==|!=|>=|<=|>|<)/ ||     # for equivalent
       str =~ /^\s*"\S*"/ ||                 # for string
       str =~ /^\s*{\S+}/ ||                 # for attribute
       str =~ /^\s*(not|and|or|true|false)/  # for binary operator
      token = $~[0]
      @next_pos += token.length
#      puts @str[@next_pos..-1]
      return token.gsub(/\s*/, "")
    end
    
    nil
  end
  
  def commit_token
    @pos = @next_pos
  end

  def solve str
    initialize @document
    @str = str
    next_expr
  end

  def next_expr
    next_disjunction
  end

  def next_disjunction
    a = next_conjunction
    token = peek_token
    while token == "or"
      commit_token
      b = next_conjunction
      token = peek_token
      a = a | b
    end
    return a
  end

  def next_conjunction
    a = next_inversion
    token = peek_token
    while token == "and"
      commit_token
      b = next_inversion
      token = peek_token
      a = a & b
    end
    return a
  end

  def next_inversion
    token = peek_token
    if token == "not"
      commit_token
      ret = next_inversion
      return !ret
    end
    
    return next_comparison
  end

  def next_comparison
    a = next_term
    token = peek_token
    if token == "=="
      commit_token
      b = next_term
      return a == b
    elsif token == "!="
      commit_token
      b = next_term
      return a != b
    elsif token == ">="
      commit_token
      b = next_term
      return a >= b
    elsif token == "<="
      commit_token
      b = next_term
      return a <= b
    elsif token == ">"
      commit_token
      b = next_term
      return a > b
    elsif token == "<"
      commit_token
      b = next_term
      return a < b
    else
      return a
    end
  end

  def next_term
    token = peek_token
    commit_token
    if token == "("
      a = next_expr
      token = peek_token
      commit_token
      if token != ")"
        raise ArgumentError, "Expect ')', but is #{token}"
      end
      token = a
    end

    # literal
    resolve_expr_val token
#    if token.to_s =~ /(true|false)/ 
#      return token.to_s == "true"
#    elsif token.to_s =~ /"(\S+)"/
#      return $1
#    else
#      return token
#    end
  end
  
  def resolve_expr_val val
    if ((val.start_with? '"') && (val.end_with? '"')) ||
        ((val.start_with? '\'') && (val.end_with? '\''))
      quoted = true
      val = val.gsub(/"(.+)"/, '\1')
      val = val.gsub(/'(.+)'/, '\1')
    else
      quoted = false
    end

    # QUESTION should we substitute first?
    # QUESTION should we also require string to be single quoted (like block attribute values?)
    val = @document.sub_attributes val, attribute_missing: 'drop' if val.include? ATTR_REF_HEAD
  
    if quoted
      val = val.gsub(/"(.+)"/, '\1')
      val
    elsif val.empty?
      nil
    elsif val == 'true'
      true
    elsif val == 'false'
      false
    elsif val.rstrip.empty?
      ' '
    elsif val.include? '.'
      val.to_f
    else
      # fallback to coercing to integer, since we
      # require string values to be explicitly quoted
      val.to_i
    end
  end
end
end
