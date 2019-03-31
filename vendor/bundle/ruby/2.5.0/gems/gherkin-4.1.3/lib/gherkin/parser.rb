# This file is generated. Do not edit! Edit gherkin-ruby.razor instead.
require 'gherkin/ast_builder'
require 'gherkin/token_matcher'
require 'gherkin/token_scanner'
require 'gherkin/errors'

module Gherkin

  RULE_TYPE = [
    :None,
    :_EOF, # #EOF
    :_Empty, # #Empty
    :_Comment, # #Comment
    :_TagLine, # #TagLine
    :_FeatureLine, # #FeatureLine
    :_BackgroundLine, # #BackgroundLine
    :_ScenarioLine, # #ScenarioLine
    :_ScenarioOutlineLine, # #ScenarioOutlineLine
    :_ExamplesLine, # #ExamplesLine
    :_StepLine, # #StepLine
    :_DocStringSeparator, # #DocStringSeparator
    :_TableRow, # #TableRow
    :_Language, # #Language
    :_Other, # #Other
    :GherkinDocument, # GherkinDocument! := Feature?
    :Feature, # Feature! := Feature_Header Background? Scenario_Definition*
    :Feature_Header, # Feature_Header! := #Language? Tags? #FeatureLine Feature_Description
    :Background, # Background! := #BackgroundLine Background_Description Scenario_Step*
    :Scenario_Definition, # Scenario_Definition! := Tags? (Scenario | ScenarioOutline)
    :Scenario, # Scenario! := #ScenarioLine Scenario_Description Scenario_Step*
    :ScenarioOutline, # ScenarioOutline! := #ScenarioOutlineLine ScenarioOutline_Description ScenarioOutline_Step* Examples_Definition*
    :Examples_Definition, # Examples_Definition! [#Empty|#Comment|#TagLine-&gt;#ExamplesLine] := Tags? Examples
    :Examples, # Examples! := #ExamplesLine Examples_Description Examples_Table?
    :Examples_Table, # Examples_Table! := #TableRow #TableRow*
    :Scenario_Step, # Scenario_Step := Step
    :ScenarioOutline_Step, # ScenarioOutline_Step := Step
    :Step, # Step! := #StepLine Step_Arg?
    :Step_Arg, # Step_Arg := (DataTable | DocString)
    :DataTable, # DataTable! := #TableRow+
    :DocString, # DocString! := #DocStringSeparator #Other* #DocStringSeparator
    :Tags, # Tags! := #TagLine+
    :Feature_Description, # Feature_Description := Description_Helper
    :Background_Description, # Background_Description := Description_Helper
    :Scenario_Description, # Scenario_Description := Description_Helper
    :ScenarioOutline_Description, # ScenarioOutline_Description := Description_Helper
    :Examples_Description, # Examples_Description := Description_Helper
    :Description_Helper, # Description_Helper := #Empty* Description? #Comment*
    :Description, # Description! := #Other+
  ]

  class ParserContext
    attr_reader :token_scanner, :token_matcher, :token_queue, :errors

    def initialize(token_scanner, token_matcher, token_queue, errors)
      @token_scanner = token_scanner
      @token_matcher = token_matcher
      @token_queue = token_queue
      @errors = errors
    end
  end

  class Parser
    attr_accessor :stop_at_first_error

    def initialize(ast_builder=AstBuilder.new)
      @ast_builder = ast_builder
    end

    def parse(token_scanner, token_matcher=TokenMatcher.new)
      token_scanner = token_scanner.is_a?(TokenScanner) ? token_scanner : TokenScanner.new(token_scanner)

      @ast_builder.reset
      token_matcher.reset
      context = ParserContext.new(
        token_scanner,
        token_matcher,
        [],
        []
      )

      start_rule(context, :GherkinDocument);
      state = 0
      token = nil
      begin
        token = read_token(context)
        state = match_token(state, token, context)
      end until(token.eof?)

      end_rule(context, :GherkinDocument)

      raise CompositeParserException.new(context.errors) if context.errors.any?

      get_result()
    end

    def build(context, token)
      handle_ast_error(context) do
        @ast_builder.build(token)
      end
    end

    def add_error(context, error)
      context.errors.push(error)
      raise CompositeParserException, context.errors if context.errors.length > 10
    end

    def start_rule(context, rule_type)
      handle_ast_error(context) do
        @ast_builder.start_rule(rule_type)
      end
    end

    def end_rule(context, rule_type)
      handle_ast_error(context) do
        @ast_builder.end_rule(rule_type)
      end
    end

    def get_result()
      @ast_builder.get_result
    end

    def read_token(context)
      context.token_queue.any? ? context.token_queue.shift : context.token_scanner.read
    end


    def match_EOF( context, token)
      return handle_external_error(context, false) do
        context.token_matcher.match_EOF(token)
      end
    end

    def match_Empty( context, token)
      return false if token.eof?
      return handle_external_error(context, false) do
        context.token_matcher.match_Empty(token)
      end
    end

    def match_Comment( context, token)
      return false if token.eof?
      return handle_external_error(context, false) do
        context.token_matcher.match_Comment(token)
      end
    end

    def match_TagLine( context, token)
      return false if token.eof?
      return handle_external_error(context, false) do
        context.token_matcher.match_TagLine(token)
      end
    end

    def match_FeatureLine( context, token)
      return false if token.eof?
      return handle_external_error(context, false) do
        context.token_matcher.match_FeatureLine(token)
      end
    end

    def match_BackgroundLine( context, token)
      return false if token.eof?
      return handle_external_error(context, false) do
        context.token_matcher.match_BackgroundLine(token)
      end
    end

    def match_ScenarioLine( context, token)
      return false if token.eof?
      return handle_external_error(context, false) do
        context.token_matcher.match_ScenarioLine(token)
      end
    end

    def match_ScenarioOutlineLine( context, token)
      return false if token.eof?
      return handle_external_error(context, false) do
        context.token_matcher.match_ScenarioOutlineLine(token)
      end
    end

    def match_ExamplesLine( context, token)
      return false if token.eof?
      return handle_external_error(context, false) do
        context.token_matcher.match_ExamplesLine(token)
      end
    end

    def match_StepLine( context, token)
      return false if token.eof?
      return handle_external_error(context, false) do
        context.token_matcher.match_StepLine(token)
      end
    end

    def match_DocStringSeparator( context, token)
      return false if token.eof?
      return handle_external_error(context, false) do
        context.token_matcher.match_DocStringSeparator(token)
      end
    end

    def match_TableRow( context, token)
      return false if token.eof?
      return handle_external_error(context, false) do
        context.token_matcher.match_TableRow(token)
      end
    end

    def match_Language( context, token)
      return false if token.eof?
      return handle_external_error(context, false) do
        context.token_matcher.match_Language(token)
      end
    end

    def match_Other( context, token)
      return false if token.eof?
      return handle_external_error(context, false) do
        context.token_matcher.match_Other(token)
      end
    end

    def match_token(state, token, context)
      case state
      when 0
        match_token_at_0(token, context)
      when 1
        match_token_at_1(token, context)
      when 2
        match_token_at_2(token, context)
      when 3
        match_token_at_3(token, context)
      when 4
        match_token_at_4(token, context)
      when 5
        match_token_at_5(token, context)
      when 6
        match_token_at_6(token, context)
      when 7
        match_token_at_7(token, context)
      when 8
        match_token_at_8(token, context)
      when 9
        match_token_at_9(token, context)
      when 10
        match_token_at_10(token, context)
      when 11
        match_token_at_11(token, context)
      when 12
        match_token_at_12(token, context)
      when 13
        match_token_at_13(token, context)
      when 14
        match_token_at_14(token, context)
      when 15
        match_token_at_15(token, context)
      when 16
        match_token_at_16(token, context)
      when 17
        match_token_at_17(token, context)
      when 18
        match_token_at_18(token, context)
      when 19
        match_token_at_19(token, context)
      when 20
        match_token_at_20(token, context)
      when 21
        match_token_at_21(token, context)
      when 22
        match_token_at_22(token, context)
      when 23
        match_token_at_23(token, context)
      when 24
        match_token_at_24(token, context)
      when 25
        match_token_at_25(token, context)
      when 26
        match_token_at_26(token, context)
      when 28
        match_token_at_28(token, context)
      when 29
        match_token_at_29(token, context)
      when 30
        match_token_at_30(token, context)
      when 31
        match_token_at_31(token, context)
      when 32
        match_token_at_32(token, context)
      when 33
        match_token_at_33(token, context)
      else
        raise InvalidOperationException, "Unknown state: #{state}"
      end
    end


    # Start
    def match_token_at_0(token, context)
      if match_EOF(context, token)
        build(context, token);
        return 27
      end
      if match_Language(context, token)
        start_rule(context, :Feature);
        start_rule(context, :Feature_Header);
        build(context, token);
        return 1
      end
      if match_TagLine(context, token)
        start_rule(context, :Feature);
        start_rule(context, :Feature_Header);
        start_rule(context, :Tags);
        build(context, token);
        return 2
      end
      if match_FeatureLine(context, token)
        start_rule(context, :Feature);
        start_rule(context, :Feature_Header);
        build(context, token);
        return 3
      end
      if match_Comment(context, token)
        build(context, token);
        return 0
      end
      if match_Empty(context, token)
        build(context, token);
        return 0
      end
      
      state_comment = "State: 0 - Start"
      token.detach
      expected_tokens = ["#EOF", "#Language", "#TagLine", "#FeatureLine", "#Comment", "#Empty"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 0
    end

    # GherkinDocument:0>Feature:0>Feature_Header:0>#Language:0
    def match_token_at_1(token, context)
      if match_TagLine(context, token)
        start_rule(context, :Tags);
        build(context, token);
        return 2
      end
      if match_FeatureLine(context, token)
        build(context, token);
        return 3
      end
      if match_Comment(context, token)
        build(context, token);
        return 1
      end
      if match_Empty(context, token)
        build(context, token);
        return 1
      end
      
      state_comment = "State: 1 - GherkinDocument:0>Feature:0>Feature_Header:0>#Language:0"
      token.detach
      expected_tokens = ["#TagLine", "#FeatureLine", "#Comment", "#Empty"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 1
    end

    # GherkinDocument:0>Feature:0>Feature_Header:1>Tags:0>#TagLine:0
    def match_token_at_2(token, context)
      if match_TagLine(context, token)
        build(context, token);
        return 2
      end
      if match_FeatureLine(context, token)
        end_rule(context, :Tags);
        build(context, token);
        return 3
      end
      if match_Comment(context, token)
        build(context, token);
        return 2
      end
      if match_Empty(context, token)
        build(context, token);
        return 2
      end
      
      state_comment = "State: 2 - GherkinDocument:0>Feature:0>Feature_Header:1>Tags:0>#TagLine:0"
      token.detach
      expected_tokens = ["#TagLine", "#FeatureLine", "#Comment", "#Empty"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 2
    end

    # GherkinDocument:0>Feature:0>Feature_Header:2>#FeatureLine:0
    def match_token_at_3(token, context)
      if match_EOF(context, token)
        end_rule(context, :Feature_Header);
        end_rule(context, :Feature);
        build(context, token);
        return 27
      end
      if match_Empty(context, token)
        build(context, token);
        return 3
      end
      if match_Comment(context, token)
        build(context, token);
        return 5
      end
      if match_BackgroundLine(context, token)
        end_rule(context, :Feature_Header);
        start_rule(context, :Background);
        build(context, token);
        return 6
      end
      if match_TagLine(context, token)
        end_rule(context, :Feature_Header);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 11
      end
      if match_ScenarioLine(context, token)
        end_rule(context, :Feature_Header);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario);
        build(context, token);
        return 12
      end
      if match_ScenarioOutlineLine(context, token)
        end_rule(context, :Feature_Header);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :ScenarioOutline);
        build(context, token);
        return 17
      end
      if match_Other(context, token)
        start_rule(context, :Description);
        build(context, token);
        return 4
      end
      
      state_comment = "State: 3 - GherkinDocument:0>Feature:0>Feature_Header:2>#FeatureLine:0"
      token.detach
      expected_tokens = ["#EOF", "#Empty", "#Comment", "#BackgroundLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Other"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 3
    end

    # GherkinDocument:0>Feature:0>Feature_Header:3>Feature_Description:0>Description_Helper:1>Description:0>#Other:0
    def match_token_at_4(token, context)
      if match_EOF(context, token)
        end_rule(context, :Description);
        end_rule(context, :Feature_Header);
        end_rule(context, :Feature);
        build(context, token);
        return 27
      end
      if match_Comment(context, token)
        end_rule(context, :Description);
        build(context, token);
        return 5
      end
      if match_BackgroundLine(context, token)
        end_rule(context, :Description);
        end_rule(context, :Feature_Header);
        start_rule(context, :Background);
        build(context, token);
        return 6
      end
      if match_TagLine(context, token)
        end_rule(context, :Description);
        end_rule(context, :Feature_Header);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 11
      end
      if match_ScenarioLine(context, token)
        end_rule(context, :Description);
        end_rule(context, :Feature_Header);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario);
        build(context, token);
        return 12
      end
      if match_ScenarioOutlineLine(context, token)
        end_rule(context, :Description);
        end_rule(context, :Feature_Header);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :ScenarioOutline);
        build(context, token);
        return 17
      end
      if match_Other(context, token)
        build(context, token);
        return 4
      end
      
      state_comment = "State: 4 - GherkinDocument:0>Feature:0>Feature_Header:3>Feature_Description:0>Description_Helper:1>Description:0>#Other:0"
      token.detach
      expected_tokens = ["#EOF", "#Comment", "#BackgroundLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Other"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 4
    end

    # GherkinDocument:0>Feature:0>Feature_Header:3>Feature_Description:0>Description_Helper:2>#Comment:0
    def match_token_at_5(token, context)
      if match_EOF(context, token)
        end_rule(context, :Feature_Header);
        end_rule(context, :Feature);
        build(context, token);
        return 27
      end
      if match_Comment(context, token)
        build(context, token);
        return 5
      end
      if match_BackgroundLine(context, token)
        end_rule(context, :Feature_Header);
        start_rule(context, :Background);
        build(context, token);
        return 6
      end
      if match_TagLine(context, token)
        end_rule(context, :Feature_Header);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 11
      end
      if match_ScenarioLine(context, token)
        end_rule(context, :Feature_Header);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario);
        build(context, token);
        return 12
      end
      if match_ScenarioOutlineLine(context, token)
        end_rule(context, :Feature_Header);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :ScenarioOutline);
        build(context, token);
        return 17
      end
      if match_Empty(context, token)
        build(context, token);
        return 5
      end
      
      state_comment = "State: 5 - GherkinDocument:0>Feature:0>Feature_Header:3>Feature_Description:0>Description_Helper:2>#Comment:0"
      token.detach
      expected_tokens = ["#EOF", "#Comment", "#BackgroundLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Empty"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 5
    end

    # GherkinDocument:0>Feature:1>Background:0>#BackgroundLine:0
    def match_token_at_6(token, context)
      if match_EOF(context, token)
        end_rule(context, :Background);
        end_rule(context, :Feature);
        build(context, token);
        return 27
      end
      if match_Empty(context, token)
        build(context, token);
        return 6
      end
      if match_Comment(context, token)
        build(context, token);
        return 8
      end
      if match_StepLine(context, token)
        start_rule(context, :Step);
        build(context, token);
        return 9
      end
      if match_TagLine(context, token)
        end_rule(context, :Background);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 11
      end
      if match_ScenarioLine(context, token)
        end_rule(context, :Background);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario);
        build(context, token);
        return 12
      end
      if match_ScenarioOutlineLine(context, token)
        end_rule(context, :Background);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :ScenarioOutline);
        build(context, token);
        return 17
      end
      if match_Other(context, token)
        start_rule(context, :Description);
        build(context, token);
        return 7
      end
      
      state_comment = "State: 6 - GherkinDocument:0>Feature:1>Background:0>#BackgroundLine:0"
      token.detach
      expected_tokens = ["#EOF", "#Empty", "#Comment", "#StepLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Other"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 6
    end

    # GherkinDocument:0>Feature:1>Background:1>Background_Description:0>Description_Helper:1>Description:0>#Other:0
    def match_token_at_7(token, context)
      if match_EOF(context, token)
        end_rule(context, :Description);
        end_rule(context, :Background);
        end_rule(context, :Feature);
        build(context, token);
        return 27
      end
      if match_Comment(context, token)
        end_rule(context, :Description);
        build(context, token);
        return 8
      end
      if match_StepLine(context, token)
        end_rule(context, :Description);
        start_rule(context, :Step);
        build(context, token);
        return 9
      end
      if match_TagLine(context, token)
        end_rule(context, :Description);
        end_rule(context, :Background);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 11
      end
      if match_ScenarioLine(context, token)
        end_rule(context, :Description);
        end_rule(context, :Background);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario);
        build(context, token);
        return 12
      end
      if match_ScenarioOutlineLine(context, token)
        end_rule(context, :Description);
        end_rule(context, :Background);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :ScenarioOutline);
        build(context, token);
        return 17
      end
      if match_Other(context, token)
        build(context, token);
        return 7
      end
      
      state_comment = "State: 7 - GherkinDocument:0>Feature:1>Background:1>Background_Description:0>Description_Helper:1>Description:0>#Other:0"
      token.detach
      expected_tokens = ["#EOF", "#Comment", "#StepLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Other"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 7
    end

    # GherkinDocument:0>Feature:1>Background:1>Background_Description:0>Description_Helper:2>#Comment:0
    def match_token_at_8(token, context)
      if match_EOF(context, token)
        end_rule(context, :Background);
        end_rule(context, :Feature);
        build(context, token);
        return 27
      end
      if match_Comment(context, token)
        build(context, token);
        return 8
      end
      if match_StepLine(context, token)
        start_rule(context, :Step);
        build(context, token);
        return 9
      end
      if match_TagLine(context, token)
        end_rule(context, :Background);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 11
      end
      if match_ScenarioLine(context, token)
        end_rule(context, :Background);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario);
        build(context, token);
        return 12
      end
      if match_ScenarioOutlineLine(context, token)
        end_rule(context, :Background);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :ScenarioOutline);
        build(context, token);
        return 17
      end
      if match_Empty(context, token)
        build(context, token);
        return 8
      end
      
      state_comment = "State: 8 - GherkinDocument:0>Feature:1>Background:1>Background_Description:0>Description_Helper:2>#Comment:0"
      token.detach
      expected_tokens = ["#EOF", "#Comment", "#StepLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Empty"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 8
    end

    # GherkinDocument:0>Feature:1>Background:2>Scenario_Step:0>Step:0>#StepLine:0
    def match_token_at_9(token, context)
      if match_EOF(context, token)
        end_rule(context, :Step);
        end_rule(context, :Background);
        end_rule(context, :Feature);
        build(context, token);
        return 27
      end
      if match_TableRow(context, token)
        start_rule(context, :DataTable);
        build(context, token);
        return 10
      end
      if match_DocStringSeparator(context, token)
        start_rule(context, :DocString);
        build(context, token);
        return 32
      end
      if match_StepLine(context, token)
        end_rule(context, :Step);
        start_rule(context, :Step);
        build(context, token);
        return 9
      end
      if match_TagLine(context, token)
        end_rule(context, :Step);
        end_rule(context, :Background);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 11
      end
      if match_ScenarioLine(context, token)
        end_rule(context, :Step);
        end_rule(context, :Background);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario);
        build(context, token);
        return 12
      end
      if match_ScenarioOutlineLine(context, token)
        end_rule(context, :Step);
        end_rule(context, :Background);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :ScenarioOutline);
        build(context, token);
        return 17
      end
      if match_Comment(context, token)
        build(context, token);
        return 9
      end
      if match_Empty(context, token)
        build(context, token);
        return 9
      end
      
      state_comment = "State: 9 - GherkinDocument:0>Feature:1>Background:2>Scenario_Step:0>Step:0>#StepLine:0"
      token.detach
      expected_tokens = ["#EOF", "#TableRow", "#DocStringSeparator", "#StepLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Comment", "#Empty"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 9
    end

    # GherkinDocument:0>Feature:1>Background:2>Scenario_Step:0>Step:1>Step_Arg:0>__alt1:0>DataTable:0>#TableRow:0
    def match_token_at_10(token, context)
      if match_EOF(context, token)
        end_rule(context, :DataTable);
        end_rule(context, :Step);
        end_rule(context, :Background);
        end_rule(context, :Feature);
        build(context, token);
        return 27
      end
      if match_TableRow(context, token)
        build(context, token);
        return 10
      end
      if match_StepLine(context, token)
        end_rule(context, :DataTable);
        end_rule(context, :Step);
        start_rule(context, :Step);
        build(context, token);
        return 9
      end
      if match_TagLine(context, token)
        end_rule(context, :DataTable);
        end_rule(context, :Step);
        end_rule(context, :Background);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 11
      end
      if match_ScenarioLine(context, token)
        end_rule(context, :DataTable);
        end_rule(context, :Step);
        end_rule(context, :Background);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario);
        build(context, token);
        return 12
      end
      if match_ScenarioOutlineLine(context, token)
        end_rule(context, :DataTable);
        end_rule(context, :Step);
        end_rule(context, :Background);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :ScenarioOutline);
        build(context, token);
        return 17
      end
      if match_Comment(context, token)
        build(context, token);
        return 10
      end
      if match_Empty(context, token)
        build(context, token);
        return 10
      end
      
      state_comment = "State: 10 - GherkinDocument:0>Feature:1>Background:2>Scenario_Step:0>Step:1>Step_Arg:0>__alt1:0>DataTable:0>#TableRow:0"
      token.detach
      expected_tokens = ["#EOF", "#TableRow", "#StepLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Comment", "#Empty"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 10
    end

    # GherkinDocument:0>Feature:2>Scenario_Definition:0>Tags:0>#TagLine:0
    def match_token_at_11(token, context)
      if match_TagLine(context, token)
        build(context, token);
        return 11
      end
      if match_ScenarioLine(context, token)
        end_rule(context, :Tags);
        start_rule(context, :Scenario);
        build(context, token);
        return 12
      end
      if match_ScenarioOutlineLine(context, token)
        end_rule(context, :Tags);
        start_rule(context, :ScenarioOutline);
        build(context, token);
        return 17
      end
      if match_Comment(context, token)
        build(context, token);
        return 11
      end
      if match_Empty(context, token)
        build(context, token);
        return 11
      end
      
      state_comment = "State: 11 - GherkinDocument:0>Feature:2>Scenario_Definition:0>Tags:0>#TagLine:0"
      token.detach
      expected_tokens = ["#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Comment", "#Empty"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 11
    end

    # GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:0>Scenario:0>#ScenarioLine:0
    def match_token_at_12(token, context)
      if match_EOF(context, token)
        end_rule(context, :Scenario);
        end_rule(context, :Scenario_Definition);
        end_rule(context, :Feature);
        build(context, token);
        return 27
      end
      if match_Empty(context, token)
        build(context, token);
        return 12
      end
      if match_Comment(context, token)
        build(context, token);
        return 14
      end
      if match_StepLine(context, token)
        start_rule(context, :Step);
        build(context, token);
        return 15
      end
      if match_TagLine(context, token)
        end_rule(context, :Scenario);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 11
      end
      if match_ScenarioLine(context, token)
        end_rule(context, :Scenario);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario);
        build(context, token);
        return 12
      end
      if match_ScenarioOutlineLine(context, token)
        end_rule(context, :Scenario);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :ScenarioOutline);
        build(context, token);
        return 17
      end
      if match_Other(context, token)
        start_rule(context, :Description);
        build(context, token);
        return 13
      end
      
      state_comment = "State: 12 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:0>Scenario:0>#ScenarioLine:0"
      token.detach
      expected_tokens = ["#EOF", "#Empty", "#Comment", "#StepLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Other"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 12
    end

    # GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:0>Scenario:1>Scenario_Description:0>Description_Helper:1>Description:0>#Other:0
    def match_token_at_13(token, context)
      if match_EOF(context, token)
        end_rule(context, :Description);
        end_rule(context, :Scenario);
        end_rule(context, :Scenario_Definition);
        end_rule(context, :Feature);
        build(context, token);
        return 27
      end
      if match_Comment(context, token)
        end_rule(context, :Description);
        build(context, token);
        return 14
      end
      if match_StepLine(context, token)
        end_rule(context, :Description);
        start_rule(context, :Step);
        build(context, token);
        return 15
      end
      if match_TagLine(context, token)
        end_rule(context, :Description);
        end_rule(context, :Scenario);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 11
      end
      if match_ScenarioLine(context, token)
        end_rule(context, :Description);
        end_rule(context, :Scenario);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario);
        build(context, token);
        return 12
      end
      if match_ScenarioOutlineLine(context, token)
        end_rule(context, :Description);
        end_rule(context, :Scenario);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :ScenarioOutline);
        build(context, token);
        return 17
      end
      if match_Other(context, token)
        build(context, token);
        return 13
      end
      
      state_comment = "State: 13 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:0>Scenario:1>Scenario_Description:0>Description_Helper:1>Description:0>#Other:0"
      token.detach
      expected_tokens = ["#EOF", "#Comment", "#StepLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Other"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 13
    end

    # GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:0>Scenario:1>Scenario_Description:0>Description_Helper:2>#Comment:0
    def match_token_at_14(token, context)
      if match_EOF(context, token)
        end_rule(context, :Scenario);
        end_rule(context, :Scenario_Definition);
        end_rule(context, :Feature);
        build(context, token);
        return 27
      end
      if match_Comment(context, token)
        build(context, token);
        return 14
      end
      if match_StepLine(context, token)
        start_rule(context, :Step);
        build(context, token);
        return 15
      end
      if match_TagLine(context, token)
        end_rule(context, :Scenario);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 11
      end
      if match_ScenarioLine(context, token)
        end_rule(context, :Scenario);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario);
        build(context, token);
        return 12
      end
      if match_ScenarioOutlineLine(context, token)
        end_rule(context, :Scenario);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :ScenarioOutline);
        build(context, token);
        return 17
      end
      if match_Empty(context, token)
        build(context, token);
        return 14
      end
      
      state_comment = "State: 14 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:0>Scenario:1>Scenario_Description:0>Description_Helper:2>#Comment:0"
      token.detach
      expected_tokens = ["#EOF", "#Comment", "#StepLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Empty"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 14
    end

    # GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:0>Scenario:2>Scenario_Step:0>Step:0>#StepLine:0
    def match_token_at_15(token, context)
      if match_EOF(context, token)
        end_rule(context, :Step);
        end_rule(context, :Scenario);
        end_rule(context, :Scenario_Definition);
        end_rule(context, :Feature);
        build(context, token);
        return 27
      end
      if match_TableRow(context, token)
        start_rule(context, :DataTable);
        build(context, token);
        return 16
      end
      if match_DocStringSeparator(context, token)
        start_rule(context, :DocString);
        build(context, token);
        return 30
      end
      if match_StepLine(context, token)
        end_rule(context, :Step);
        start_rule(context, :Step);
        build(context, token);
        return 15
      end
      if match_TagLine(context, token)
        end_rule(context, :Step);
        end_rule(context, :Scenario);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 11
      end
      if match_ScenarioLine(context, token)
        end_rule(context, :Step);
        end_rule(context, :Scenario);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario);
        build(context, token);
        return 12
      end
      if match_ScenarioOutlineLine(context, token)
        end_rule(context, :Step);
        end_rule(context, :Scenario);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :ScenarioOutline);
        build(context, token);
        return 17
      end
      if match_Comment(context, token)
        build(context, token);
        return 15
      end
      if match_Empty(context, token)
        build(context, token);
        return 15
      end
      
      state_comment = "State: 15 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:0>Scenario:2>Scenario_Step:0>Step:0>#StepLine:0"
      token.detach
      expected_tokens = ["#EOF", "#TableRow", "#DocStringSeparator", "#StepLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Comment", "#Empty"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 15
    end

    # GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:0>Scenario:2>Scenario_Step:0>Step:1>Step_Arg:0>__alt1:0>DataTable:0>#TableRow:0
    def match_token_at_16(token, context)
      if match_EOF(context, token)
        end_rule(context, :DataTable);
        end_rule(context, :Step);
        end_rule(context, :Scenario);
        end_rule(context, :Scenario_Definition);
        end_rule(context, :Feature);
        build(context, token);
        return 27
      end
      if match_TableRow(context, token)
        build(context, token);
        return 16
      end
      if match_StepLine(context, token)
        end_rule(context, :DataTable);
        end_rule(context, :Step);
        start_rule(context, :Step);
        build(context, token);
        return 15
      end
      if match_TagLine(context, token)
        end_rule(context, :DataTable);
        end_rule(context, :Step);
        end_rule(context, :Scenario);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 11
      end
      if match_ScenarioLine(context, token)
        end_rule(context, :DataTable);
        end_rule(context, :Step);
        end_rule(context, :Scenario);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario);
        build(context, token);
        return 12
      end
      if match_ScenarioOutlineLine(context, token)
        end_rule(context, :DataTable);
        end_rule(context, :Step);
        end_rule(context, :Scenario);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :ScenarioOutline);
        build(context, token);
        return 17
      end
      if match_Comment(context, token)
        build(context, token);
        return 16
      end
      if match_Empty(context, token)
        build(context, token);
        return 16
      end
      
      state_comment = "State: 16 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:0>Scenario:2>Scenario_Step:0>Step:1>Step_Arg:0>__alt1:0>DataTable:0>#TableRow:0"
      token.detach
      expected_tokens = ["#EOF", "#TableRow", "#StepLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Comment", "#Empty"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 16
    end

    # GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:0>#ScenarioOutlineLine:0
    def match_token_at_17(token, context)
      if match_EOF(context, token)
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        end_rule(context, :Feature);
        build(context, token);
        return 27
      end
      if match_Empty(context, token)
        build(context, token);
        return 17
      end
      if match_Comment(context, token)
        build(context, token);
        return 19
      end
      if match_StepLine(context, token)
        start_rule(context, :Step);
        build(context, token);
        return 20
      end
      if match_TagLine(context, token)
        if lookahead_0(context, token)
        start_rule(context, :Examples_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 22
        end
      end
      if match_TagLine(context, token)
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 11
      end
      if match_ExamplesLine(context, token)
        start_rule(context, :Examples_Definition);
        start_rule(context, :Examples);
        build(context, token);
        return 23
      end
      if match_ScenarioLine(context, token)
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario);
        build(context, token);
        return 12
      end
      if match_ScenarioOutlineLine(context, token)
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :ScenarioOutline);
        build(context, token);
        return 17
      end
      if match_Other(context, token)
        start_rule(context, :Description);
        build(context, token);
        return 18
      end
      
      state_comment = "State: 17 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:0>#ScenarioOutlineLine:0"
      token.detach
      expected_tokens = ["#EOF", "#Empty", "#Comment", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Other"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 17
    end

    # GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:1>ScenarioOutline_Description:0>Description_Helper:1>Description:0>#Other:0
    def match_token_at_18(token, context)
      if match_EOF(context, token)
        end_rule(context, :Description);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        end_rule(context, :Feature);
        build(context, token);
        return 27
      end
      if match_Comment(context, token)
        end_rule(context, :Description);
        build(context, token);
        return 19
      end
      if match_StepLine(context, token)
        end_rule(context, :Description);
        start_rule(context, :Step);
        build(context, token);
        return 20
      end
      if match_TagLine(context, token)
        if lookahead_0(context, token)
        end_rule(context, :Description);
        start_rule(context, :Examples_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 22
        end
      end
      if match_TagLine(context, token)
        end_rule(context, :Description);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 11
      end
      if match_ExamplesLine(context, token)
        end_rule(context, :Description);
        start_rule(context, :Examples_Definition);
        start_rule(context, :Examples);
        build(context, token);
        return 23
      end
      if match_ScenarioLine(context, token)
        end_rule(context, :Description);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario);
        build(context, token);
        return 12
      end
      if match_ScenarioOutlineLine(context, token)
        end_rule(context, :Description);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :ScenarioOutline);
        build(context, token);
        return 17
      end
      if match_Other(context, token)
        build(context, token);
        return 18
      end
      
      state_comment = "State: 18 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:1>ScenarioOutline_Description:0>Description_Helper:1>Description:0>#Other:0"
      token.detach
      expected_tokens = ["#EOF", "#Comment", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Other"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 18
    end

    # GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:1>ScenarioOutline_Description:0>Description_Helper:2>#Comment:0
    def match_token_at_19(token, context)
      if match_EOF(context, token)
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        end_rule(context, :Feature);
        build(context, token);
        return 27
      end
      if match_Comment(context, token)
        build(context, token);
        return 19
      end
      if match_StepLine(context, token)
        start_rule(context, :Step);
        build(context, token);
        return 20
      end
      if match_TagLine(context, token)
        if lookahead_0(context, token)
        start_rule(context, :Examples_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 22
        end
      end
      if match_TagLine(context, token)
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 11
      end
      if match_ExamplesLine(context, token)
        start_rule(context, :Examples_Definition);
        start_rule(context, :Examples);
        build(context, token);
        return 23
      end
      if match_ScenarioLine(context, token)
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario);
        build(context, token);
        return 12
      end
      if match_ScenarioOutlineLine(context, token)
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :ScenarioOutline);
        build(context, token);
        return 17
      end
      if match_Empty(context, token)
        build(context, token);
        return 19
      end
      
      state_comment = "State: 19 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:1>ScenarioOutline_Description:0>Description_Helper:2>#Comment:0"
      token.detach
      expected_tokens = ["#EOF", "#Comment", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Empty"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 19
    end

    # GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:2>ScenarioOutline_Step:0>Step:0>#StepLine:0
    def match_token_at_20(token, context)
      if match_EOF(context, token)
        end_rule(context, :Step);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        end_rule(context, :Feature);
        build(context, token);
        return 27
      end
      if match_TableRow(context, token)
        start_rule(context, :DataTable);
        build(context, token);
        return 21
      end
      if match_DocStringSeparator(context, token)
        start_rule(context, :DocString);
        build(context, token);
        return 28
      end
      if match_StepLine(context, token)
        end_rule(context, :Step);
        start_rule(context, :Step);
        build(context, token);
        return 20
      end
      if match_TagLine(context, token)
        if lookahead_0(context, token)
        end_rule(context, :Step);
        start_rule(context, :Examples_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 22
        end
      end
      if match_TagLine(context, token)
        end_rule(context, :Step);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 11
      end
      if match_ExamplesLine(context, token)
        end_rule(context, :Step);
        start_rule(context, :Examples_Definition);
        start_rule(context, :Examples);
        build(context, token);
        return 23
      end
      if match_ScenarioLine(context, token)
        end_rule(context, :Step);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario);
        build(context, token);
        return 12
      end
      if match_ScenarioOutlineLine(context, token)
        end_rule(context, :Step);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :ScenarioOutline);
        build(context, token);
        return 17
      end
      if match_Comment(context, token)
        build(context, token);
        return 20
      end
      if match_Empty(context, token)
        build(context, token);
        return 20
      end
      
      state_comment = "State: 20 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:2>ScenarioOutline_Step:0>Step:0>#StepLine:0"
      token.detach
      expected_tokens = ["#EOF", "#TableRow", "#DocStringSeparator", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Comment", "#Empty"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 20
    end

    # GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:2>ScenarioOutline_Step:0>Step:1>Step_Arg:0>__alt1:0>DataTable:0>#TableRow:0
    def match_token_at_21(token, context)
      if match_EOF(context, token)
        end_rule(context, :DataTable);
        end_rule(context, :Step);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        end_rule(context, :Feature);
        build(context, token);
        return 27
      end
      if match_TableRow(context, token)
        build(context, token);
        return 21
      end
      if match_StepLine(context, token)
        end_rule(context, :DataTable);
        end_rule(context, :Step);
        start_rule(context, :Step);
        build(context, token);
        return 20
      end
      if match_TagLine(context, token)
        if lookahead_0(context, token)
        end_rule(context, :DataTable);
        end_rule(context, :Step);
        start_rule(context, :Examples_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 22
        end
      end
      if match_TagLine(context, token)
        end_rule(context, :DataTable);
        end_rule(context, :Step);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 11
      end
      if match_ExamplesLine(context, token)
        end_rule(context, :DataTable);
        end_rule(context, :Step);
        start_rule(context, :Examples_Definition);
        start_rule(context, :Examples);
        build(context, token);
        return 23
      end
      if match_ScenarioLine(context, token)
        end_rule(context, :DataTable);
        end_rule(context, :Step);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario);
        build(context, token);
        return 12
      end
      if match_ScenarioOutlineLine(context, token)
        end_rule(context, :DataTable);
        end_rule(context, :Step);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :ScenarioOutline);
        build(context, token);
        return 17
      end
      if match_Comment(context, token)
        build(context, token);
        return 21
      end
      if match_Empty(context, token)
        build(context, token);
        return 21
      end
      
      state_comment = "State: 21 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:2>ScenarioOutline_Step:0>Step:1>Step_Arg:0>__alt1:0>DataTable:0>#TableRow:0"
      token.detach
      expected_tokens = ["#EOF", "#TableRow", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Comment", "#Empty"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 21
    end

    # GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:3>Examples_Definition:0>Tags:0>#TagLine:0
    def match_token_at_22(token, context)
      if match_TagLine(context, token)
        build(context, token);
        return 22
      end
      if match_ExamplesLine(context, token)
        end_rule(context, :Tags);
        start_rule(context, :Examples);
        build(context, token);
        return 23
      end
      if match_Comment(context, token)
        build(context, token);
        return 22
      end
      if match_Empty(context, token)
        build(context, token);
        return 22
      end
      
      state_comment = "State: 22 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:3>Examples_Definition:0>Tags:0>#TagLine:0"
      token.detach
      expected_tokens = ["#TagLine", "#ExamplesLine", "#Comment", "#Empty"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 22
    end

    # GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:3>Examples_Definition:1>Examples:0>#ExamplesLine:0
    def match_token_at_23(token, context)
      if match_EOF(context, token)
        end_rule(context, :Examples);
        end_rule(context, :Examples_Definition);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        end_rule(context, :Feature);
        build(context, token);
        return 27
      end
      if match_Empty(context, token)
        build(context, token);
        return 23
      end
      if match_Comment(context, token)
        build(context, token);
        return 25
      end
      if match_TableRow(context, token)
        start_rule(context, :Examples_Table);
        build(context, token);
        return 26
      end
      if match_TagLine(context, token)
        if lookahead_0(context, token)
        end_rule(context, :Examples);
        end_rule(context, :Examples_Definition);
        start_rule(context, :Examples_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 22
        end
      end
      if match_TagLine(context, token)
        end_rule(context, :Examples);
        end_rule(context, :Examples_Definition);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 11
      end
      if match_ExamplesLine(context, token)
        end_rule(context, :Examples);
        end_rule(context, :Examples_Definition);
        start_rule(context, :Examples_Definition);
        start_rule(context, :Examples);
        build(context, token);
        return 23
      end
      if match_ScenarioLine(context, token)
        end_rule(context, :Examples);
        end_rule(context, :Examples_Definition);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario);
        build(context, token);
        return 12
      end
      if match_ScenarioOutlineLine(context, token)
        end_rule(context, :Examples);
        end_rule(context, :Examples_Definition);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :ScenarioOutline);
        build(context, token);
        return 17
      end
      if match_Other(context, token)
        start_rule(context, :Description);
        build(context, token);
        return 24
      end
      
      state_comment = "State: 23 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:3>Examples_Definition:1>Examples:0>#ExamplesLine:0"
      token.detach
      expected_tokens = ["#EOF", "#Empty", "#Comment", "#TableRow", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Other"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 23
    end

    # GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:3>Examples_Definition:1>Examples:1>Examples_Description:0>Description_Helper:1>Description:0>#Other:0
    def match_token_at_24(token, context)
      if match_EOF(context, token)
        end_rule(context, :Description);
        end_rule(context, :Examples);
        end_rule(context, :Examples_Definition);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        end_rule(context, :Feature);
        build(context, token);
        return 27
      end
      if match_Comment(context, token)
        end_rule(context, :Description);
        build(context, token);
        return 25
      end
      if match_TableRow(context, token)
        end_rule(context, :Description);
        start_rule(context, :Examples_Table);
        build(context, token);
        return 26
      end
      if match_TagLine(context, token)
        if lookahead_0(context, token)
        end_rule(context, :Description);
        end_rule(context, :Examples);
        end_rule(context, :Examples_Definition);
        start_rule(context, :Examples_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 22
        end
      end
      if match_TagLine(context, token)
        end_rule(context, :Description);
        end_rule(context, :Examples);
        end_rule(context, :Examples_Definition);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 11
      end
      if match_ExamplesLine(context, token)
        end_rule(context, :Description);
        end_rule(context, :Examples);
        end_rule(context, :Examples_Definition);
        start_rule(context, :Examples_Definition);
        start_rule(context, :Examples);
        build(context, token);
        return 23
      end
      if match_ScenarioLine(context, token)
        end_rule(context, :Description);
        end_rule(context, :Examples);
        end_rule(context, :Examples_Definition);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario);
        build(context, token);
        return 12
      end
      if match_ScenarioOutlineLine(context, token)
        end_rule(context, :Description);
        end_rule(context, :Examples);
        end_rule(context, :Examples_Definition);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :ScenarioOutline);
        build(context, token);
        return 17
      end
      if match_Other(context, token)
        build(context, token);
        return 24
      end
      
      state_comment = "State: 24 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:3>Examples_Definition:1>Examples:1>Examples_Description:0>Description_Helper:1>Description:0>#Other:0"
      token.detach
      expected_tokens = ["#EOF", "#Comment", "#TableRow", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Other"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 24
    end

    # GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:3>Examples_Definition:1>Examples:1>Examples_Description:0>Description_Helper:2>#Comment:0
    def match_token_at_25(token, context)
      if match_EOF(context, token)
        end_rule(context, :Examples);
        end_rule(context, :Examples_Definition);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        end_rule(context, :Feature);
        build(context, token);
        return 27
      end
      if match_Comment(context, token)
        build(context, token);
        return 25
      end
      if match_TableRow(context, token)
        start_rule(context, :Examples_Table);
        build(context, token);
        return 26
      end
      if match_TagLine(context, token)
        if lookahead_0(context, token)
        end_rule(context, :Examples);
        end_rule(context, :Examples_Definition);
        start_rule(context, :Examples_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 22
        end
      end
      if match_TagLine(context, token)
        end_rule(context, :Examples);
        end_rule(context, :Examples_Definition);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 11
      end
      if match_ExamplesLine(context, token)
        end_rule(context, :Examples);
        end_rule(context, :Examples_Definition);
        start_rule(context, :Examples_Definition);
        start_rule(context, :Examples);
        build(context, token);
        return 23
      end
      if match_ScenarioLine(context, token)
        end_rule(context, :Examples);
        end_rule(context, :Examples_Definition);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario);
        build(context, token);
        return 12
      end
      if match_ScenarioOutlineLine(context, token)
        end_rule(context, :Examples);
        end_rule(context, :Examples_Definition);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :ScenarioOutline);
        build(context, token);
        return 17
      end
      if match_Empty(context, token)
        build(context, token);
        return 25
      end
      
      state_comment = "State: 25 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:3>Examples_Definition:1>Examples:1>Examples_Description:0>Description_Helper:2>#Comment:0"
      token.detach
      expected_tokens = ["#EOF", "#Comment", "#TableRow", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Empty"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 25
    end

    # GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:3>Examples_Definition:1>Examples:2>Examples_Table:0>#TableRow:0
    def match_token_at_26(token, context)
      if match_EOF(context, token)
        end_rule(context, :Examples_Table);
        end_rule(context, :Examples);
        end_rule(context, :Examples_Definition);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        end_rule(context, :Feature);
        build(context, token);
        return 27
      end
      if match_TableRow(context, token)
        build(context, token);
        return 26
      end
      if match_TagLine(context, token)
        if lookahead_0(context, token)
        end_rule(context, :Examples_Table);
        end_rule(context, :Examples);
        end_rule(context, :Examples_Definition);
        start_rule(context, :Examples_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 22
        end
      end
      if match_TagLine(context, token)
        end_rule(context, :Examples_Table);
        end_rule(context, :Examples);
        end_rule(context, :Examples_Definition);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 11
      end
      if match_ExamplesLine(context, token)
        end_rule(context, :Examples_Table);
        end_rule(context, :Examples);
        end_rule(context, :Examples_Definition);
        start_rule(context, :Examples_Definition);
        start_rule(context, :Examples);
        build(context, token);
        return 23
      end
      if match_ScenarioLine(context, token)
        end_rule(context, :Examples_Table);
        end_rule(context, :Examples);
        end_rule(context, :Examples_Definition);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario);
        build(context, token);
        return 12
      end
      if match_ScenarioOutlineLine(context, token)
        end_rule(context, :Examples_Table);
        end_rule(context, :Examples);
        end_rule(context, :Examples_Definition);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :ScenarioOutline);
        build(context, token);
        return 17
      end
      if match_Comment(context, token)
        build(context, token);
        return 26
      end
      if match_Empty(context, token)
        build(context, token);
        return 26
      end
      
      state_comment = "State: 26 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:3>Examples_Definition:1>Examples:2>Examples_Table:0>#TableRow:0"
      token.detach
      expected_tokens = ["#EOF", "#TableRow", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Comment", "#Empty"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 26
    end

    # GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:2>ScenarioOutline_Step:0>Step:1>Step_Arg:0>__alt1:1>DocString:0>#DocStringSeparator:0
    def match_token_at_28(token, context)
      if match_DocStringSeparator(context, token)
        build(context, token);
        return 29
      end
      if match_Other(context, token)
        build(context, token);
        return 28
      end
      
      state_comment = "State: 28 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:2>ScenarioOutline_Step:0>Step:1>Step_Arg:0>__alt1:1>DocString:0>#DocStringSeparator:0"
      token.detach
      expected_tokens = ["#DocStringSeparator", "#Other"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 28
    end

    # GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:2>ScenarioOutline_Step:0>Step:1>Step_Arg:0>__alt1:1>DocString:2>#DocStringSeparator:0
    def match_token_at_29(token, context)
      if match_EOF(context, token)
        end_rule(context, :DocString);
        end_rule(context, :Step);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        end_rule(context, :Feature);
        build(context, token);
        return 27
      end
      if match_StepLine(context, token)
        end_rule(context, :DocString);
        end_rule(context, :Step);
        start_rule(context, :Step);
        build(context, token);
        return 20
      end
      if match_TagLine(context, token)
        if lookahead_0(context, token)
        end_rule(context, :DocString);
        end_rule(context, :Step);
        start_rule(context, :Examples_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 22
        end
      end
      if match_TagLine(context, token)
        end_rule(context, :DocString);
        end_rule(context, :Step);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 11
      end
      if match_ExamplesLine(context, token)
        end_rule(context, :DocString);
        end_rule(context, :Step);
        start_rule(context, :Examples_Definition);
        start_rule(context, :Examples);
        build(context, token);
        return 23
      end
      if match_ScenarioLine(context, token)
        end_rule(context, :DocString);
        end_rule(context, :Step);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario);
        build(context, token);
        return 12
      end
      if match_ScenarioOutlineLine(context, token)
        end_rule(context, :DocString);
        end_rule(context, :Step);
        end_rule(context, :ScenarioOutline);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :ScenarioOutline);
        build(context, token);
        return 17
      end
      if match_Comment(context, token)
        build(context, token);
        return 29
      end
      if match_Empty(context, token)
        build(context, token);
        return 29
      end
      
      state_comment = "State: 29 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:2>ScenarioOutline_Step:0>Step:1>Step_Arg:0>__alt1:1>DocString:2>#DocStringSeparator:0"
      token.detach
      expected_tokens = ["#EOF", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Comment", "#Empty"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 29
    end

    # GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:0>Scenario:2>Scenario_Step:0>Step:1>Step_Arg:0>__alt1:1>DocString:0>#DocStringSeparator:0
    def match_token_at_30(token, context)
      if match_DocStringSeparator(context, token)
        build(context, token);
        return 31
      end
      if match_Other(context, token)
        build(context, token);
        return 30
      end
      
      state_comment = "State: 30 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:0>Scenario:2>Scenario_Step:0>Step:1>Step_Arg:0>__alt1:1>DocString:0>#DocStringSeparator:0"
      token.detach
      expected_tokens = ["#DocStringSeparator", "#Other"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 30
    end

    # GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:0>Scenario:2>Scenario_Step:0>Step:1>Step_Arg:0>__alt1:1>DocString:2>#DocStringSeparator:0
    def match_token_at_31(token, context)
      if match_EOF(context, token)
        end_rule(context, :DocString);
        end_rule(context, :Step);
        end_rule(context, :Scenario);
        end_rule(context, :Scenario_Definition);
        end_rule(context, :Feature);
        build(context, token);
        return 27
      end
      if match_StepLine(context, token)
        end_rule(context, :DocString);
        end_rule(context, :Step);
        start_rule(context, :Step);
        build(context, token);
        return 15
      end
      if match_TagLine(context, token)
        end_rule(context, :DocString);
        end_rule(context, :Step);
        end_rule(context, :Scenario);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 11
      end
      if match_ScenarioLine(context, token)
        end_rule(context, :DocString);
        end_rule(context, :Step);
        end_rule(context, :Scenario);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario);
        build(context, token);
        return 12
      end
      if match_ScenarioOutlineLine(context, token)
        end_rule(context, :DocString);
        end_rule(context, :Step);
        end_rule(context, :Scenario);
        end_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :ScenarioOutline);
        build(context, token);
        return 17
      end
      if match_Comment(context, token)
        build(context, token);
        return 31
      end
      if match_Empty(context, token)
        build(context, token);
        return 31
      end
      
      state_comment = "State: 31 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:0>Scenario:2>Scenario_Step:0>Step:1>Step_Arg:0>__alt1:1>DocString:2>#DocStringSeparator:0"
      token.detach
      expected_tokens = ["#EOF", "#StepLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Comment", "#Empty"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 31
    end

    # GherkinDocument:0>Feature:1>Background:2>Scenario_Step:0>Step:1>Step_Arg:0>__alt1:1>DocString:0>#DocStringSeparator:0
    def match_token_at_32(token, context)
      if match_DocStringSeparator(context, token)
        build(context, token);
        return 33
      end
      if match_Other(context, token)
        build(context, token);
        return 32
      end
      
      state_comment = "State: 32 - GherkinDocument:0>Feature:1>Background:2>Scenario_Step:0>Step:1>Step_Arg:0>__alt1:1>DocString:0>#DocStringSeparator:0"
      token.detach
      expected_tokens = ["#DocStringSeparator", "#Other"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 32
    end

    # GherkinDocument:0>Feature:1>Background:2>Scenario_Step:0>Step:1>Step_Arg:0>__alt1:1>DocString:2>#DocStringSeparator:0
    def match_token_at_33(token, context)
      if match_EOF(context, token)
        end_rule(context, :DocString);
        end_rule(context, :Step);
        end_rule(context, :Background);
        end_rule(context, :Feature);
        build(context, token);
        return 27
      end
      if match_StepLine(context, token)
        end_rule(context, :DocString);
        end_rule(context, :Step);
        start_rule(context, :Step);
        build(context, token);
        return 9
      end
      if match_TagLine(context, token)
        end_rule(context, :DocString);
        end_rule(context, :Step);
        end_rule(context, :Background);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Tags);
        build(context, token);
        return 11
      end
      if match_ScenarioLine(context, token)
        end_rule(context, :DocString);
        end_rule(context, :Step);
        end_rule(context, :Background);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :Scenario);
        build(context, token);
        return 12
      end
      if match_ScenarioOutlineLine(context, token)
        end_rule(context, :DocString);
        end_rule(context, :Step);
        end_rule(context, :Background);
        start_rule(context, :Scenario_Definition);
        start_rule(context, :ScenarioOutline);
        build(context, token);
        return 17
      end
      if match_Comment(context, token)
        build(context, token);
        return 33
      end
      if match_Empty(context, token)
        build(context, token);
        return 33
      end
      
      state_comment = "State: 33 - GherkinDocument:0>Feature:1>Background:2>Scenario_Step:0>Step:1>Step_Arg:0>__alt1:1>DocString:2>#DocStringSeparator:0"
      token.detach
      expected_tokens = ["#EOF", "#StepLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Comment", "#Empty"]
      error = token.eof? ? UnexpectedEOFException.new(token, expected_tokens, state_comment) : UnexpectedTokenException.new(token, expected_tokens, state_comment)
      raise error if (stop_at_first_error)
      add_error(context, error)
      return 33
    end

    
    def lookahead_0(context, currentToken)
      currentToken.detach
      token = nil
      queue = []
      match = false
      loop do
        token = read_token(context)
        token.detach
        queue.push(token)

        if (false || match_ExamplesLine(context, token))
          match = true
          break
        end

        break unless (false || match_Empty(context, token)|| match_Comment(context, token)|| match_TagLine(context, token))
      end

      context.token_queue.concat(queue)

      return match
    end
    

    private

    def handle_ast_error(context, &action)
      handle_external_error(context, true, &action)
    end

    def handle_external_error(context, default_value, &action)
      return action.call if stop_at_first_error

      begin
        return action.call
      rescue CompositeParserException => e
        e.errors.each { |error| add_error(context, error) }
      rescue ParserException => e
        add_error(context, e)
      end
      default_value
    end

  end
end
