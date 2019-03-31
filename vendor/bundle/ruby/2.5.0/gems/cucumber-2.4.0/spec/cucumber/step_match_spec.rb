# encoding: utf-8
require 'spec_helper'
require 'cucumber/rb_support/rb_step_definition'
require 'cucumber/rb_support/rb_language'

module Cucumber
  describe StepMatch do
    WORD = '[[:word:]]'

    before do
      @rb_language = RbSupport::RbLanguage.new(nil, Configuration.new)
    end

    def stepdef(regexp)
      RbSupport::RbStepDefinition.new(@rb_language, regexp, lambda{}, {})
    end

    def step_match(regexp, name)
      stepdef = stepdef(regexp)
      StepMatch.new(stepdef, name, stepdef.arguments_from(name))
    end

    it "formats step names" do
      m = step_match(/it (.*) in (.*)/, "it snows in april")
      format = m.format_args("[%s]")
      expect(format).to eq "it [snows] in [april]"
    end

    it "formats one group when we use Unicode" do
      m = step_match(/I (#{WORD}+) ok/, "I æøåÆØÅæøåÆØÅæøåÆØÅæøåÆØÅ ok")

      expect(m.format_args("<span>%s</span>")).to eq "I <span>æøåÆØÅæøåÆØÅæøåÆØÅæøåÆØÅ</span> ok"
    end

    it "formats several groups when we use Unicode" do
      m = step_match(/I (#{WORD}+) (#{WORD}+) (#{WORD}+) this (#{WORD}+)/, "I ate æøåÆØÅæøåÆØÅæøåÆØÅæøåÆØÅ egg this morning")

      expect(m.format_args("<span>%s</span>")).to eq "I <span>ate</span> <span>æøåÆØÅæøåÆØÅæøåÆØÅæøåÆØÅ</span> <span>egg</span> this <span>morning</span>"
    end

    it "deals with Unicode both inside and outside arguments" do
      expect("Jæ vø ålsker døtte løndet").to match /Jæ (.+) ålsker (.+) løndet/

      m = step_match(/Jæ (#{WORD}+) ålsker (#{WORD}+) løndet/, "Jæ vø ålsker døtte løndet")

      expect(m.format_args("<span>%s</span>")).to eq "Jæ <span>vø</span> ålsker <span>døtte</span> løndet"
    end

    it "formats groups with format string" do
      m = step_match(/I (#{WORD}+) (\d+) (#{WORD}+) this (#{WORD}+)/, "I ate 1 egg this morning")

      expect(m.format_args("<span>%s</span>")).to eq "I <span>ate</span> <span>1</span> <span>egg</span> this <span>morning</span>"
    end

    it "formats groups with format string when there are dupes" do
      m = step_match(/I (#{WORD}+) (\d+) (#{WORD}+) this (#{WORD}+)/, "I bob 1 bo this bobs")

      expect(m.format_args("<span>%s</span>")).to eq "I <span>bob</span> <span>1</span> <span>bo</span> this <span>bobs</span>"
    end

    it "formats groups with block" do
      m = step_match(/I (#{WORD}+) (\d+) (#{WORD}+) this (#{WORD}+)/, "I ate 1 egg this morning")

      expect(m.format_args(&lambda{|m| "<span>#{m}</span>"})).to eq "I <span>ate</span> <span>1</span> <span>egg</span> this <span>morning</span>"
    end

    it "formats groups with proc object" do
      m = step_match(/I (#{WORD}+) (\d+) (#{WORD}+) this (#{WORD}+)/, "I ate 1 egg this morning")

      expect(m.format_args(lambda{|m| "<span>#{m}</span>"})).to eq "I <span>ate</span> <span>1</span> <span>egg</span> this <span>morning</span>"
    end

    it "formats groups even when first group is optional and not matched" do
      m = step_match(/should( not)? be flashed '([^']*?)'$/, "I should be flashed 'Login failed.'")

      expect(m.format_args("<span>%s</span>")).to eq "I should be flashed '<span>Login failed.</span>'"
    end

    it "formats embedded groups" do
      m = step_match(/running( (\d+) times)? (\d+) meters/, "running 5 times 10 meters")

      expect(m.format_args("<span>%s</span>")).to eq "running<span> 5 times</span> <span>10</span> meters"
    end
  end
end
