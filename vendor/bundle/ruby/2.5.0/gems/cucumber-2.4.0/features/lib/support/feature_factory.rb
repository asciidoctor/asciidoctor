# -*- coding: utf-8 -*-
module FeatureFactory
  def create_feature(name = generate_feature_name)
    gherkin = <<-GHERKIN
Feature: #{name}
#{yield}
    GHERKIN
    write_file filename(name), gherkin
  end

  def create_feature_ja(name = generate_feature_name)
    gherkin = <<-GHERKIN
# language: ja
機能: #{name}
#{yield}
    GHERKIN
    write_file filename(name), gherkin
  end

  def create_scenario(name = generate_scenario_name)
    <<-GHERKIN
  Scenario: #{name}
  #{yield}
    GHERKIN
  end

  def create_scenario_ja(name = generate_scenario_name)
    <<-GHERKIN
  シナリオ: #{name}
  #{yield}
    GHERKIN
  end

  def create_step_definition
    write_file generate_step_definition_filename, yield
  end

  def generate_feature_name
    "Test Feature #{next_increment(:feature)}"
  end

  def generate_scenario_name
    "Test Scenario #{next_increment(:scenario)}"
  end

  def next_increment(label)
    @increments ||= {}
    @increments[label] ||= 0
    @increments[label] += 1
  end

  def generate_step_definition_filename
    "features/step_definitions/steps#{next_increment(:step_defs)}.rb"
  end

  def filename(name)
    "features/#{name.downcase.gsub(' ', '_')}.feature"
  end

  def features
    in_current_dir do
      Dir['features/*.feature']
    end
  end
end

World(FeatureFactory)
