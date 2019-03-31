require 'spec_helper'
require 'yaml'

module Cucumber
module Cli
  describe Configuration do
    module ExposesOptions
      attr_reader :options
    end

    def given_cucumber_yml_defined_as(hash_or_string)
      allow(File).to receive(:exist?) { true }

      cucumber_yml = hash_or_string.is_a?(Hash) ? hash_or_string.to_yaml : hash_or_string

      allow(IO).to receive(:read).with('cucumber.yml') { cucumber_yml }
    end

    def given_the_following_files(*files)
      allow(File).to receive(:directory?) { true }
      allow(File).to receive(:file?) { true }
      allow(Dir).to receive(:[]) { files }
    end

    before(:each) do
      allow(File).to receive(:exist?) { false } # Meaning, no cucumber.yml exists
      allow(Kernel).to receive(:exit)
    end

    def config
      @config ||= Configuration.new(@out = StringIO.new, @error = StringIO.new).extend(ExposesOptions)
    end

    def reset_config
      @config = nil
    end

    attr_reader :out, :error

    it "uses the default profile when no profile is defined" do
      given_cucumber_yml_defined_as({'default' => '--require some_file'})

      config.parse!(%w{--format progress})

      expect(config.options[:require]).to include('some_file')
    end

    context '--profile' do
      include RSpec::WorkInProgress

      it "expands args from profiles in the cucumber.yml file" do
        given_cucumber_yml_defined_as({'bongo' => '--require from/yml'})

        config.parse!(%w{--format progress --profile bongo})

        expect(config.options[:formats]).to eq [['progress', out]]
        expect(config.options[:require]).to eq ['from/yml']
      end

      it "expands args from the default profile when no flags are provided" do
        given_cucumber_yml_defined_as({'default' => '--require from/yml'})

        config.parse!([])

        expect(config.options[:require]).to eq ['from/yml']
      end

      it "allows --strict to be set by a profile" do
        given_cucumber_yml_defined_as({'bongo' => '--strict'})

        config.parse!(%w{--profile bongo})

        expect(config.options[:strict]).to be true
      end

      it "parses ERB syntax in the cucumber.yml file" do
        given_cucumber_yml_defined_as("---\ndefault: \"<%=\"--require some_file\"%>\"\n")

        config.parse!([])

        expect(config.options[:require]).to include('some_file')
      end

      it "parses ERB in cucumber.yml that makes uses nested ERB sessions" do
        given_cucumber_yml_defined_as(<<ERB_YML)
<%= ERB.new({'standard' => '--require some_file'}.to_yaml).result %>
<%= ERB.new({'enhanced' => '--require other_file'}.to_yaml).result %>
ERB_YML

        config.parse!(%w(-p standard))

        expect(config.options[:require]).to include('some_file')
      end

      it "provides a helpful error message when a specified profile does not exists in cucumber.yml" do
        given_cucumber_yml_defined_as({'default' => '--require from/yml', 'html_report' =>  '--format html'})

        expected_message = <<-END_OF_MESSAGE
Could not find profile: 'i_do_not_exist'

Defined profiles in cucumber.yml:
  * default
  * html_report
END_OF_MESSAGE

        expect(-> { config.parse!(%w{--profile i_do_not_exist}) }).to raise_error(ProfileNotFound, expected_message)
      end

      it "allows profiles to be defined in arrays" do
        given_cucumber_yml_defined_as({'foo' => ['-f','progress']})

        config.parse!(%w{--profile foo})

        expect(config.options[:formats]).to eq [['progress', out]]
      end

      it "disregards default STDOUT formatter defined in profile when another is passed in (via cmd line)" do
        given_cucumber_yml_defined_as({'foo' => %w[--format pretty]})
        config.parse!(%w{--format progress --profile foo})

        expect(config.options[:formats]).to eq [['progress', out]]
      end

      ["--no-profile", "-P"].each do |flag|
        context 'when none is specified with #{flag}' do
          it "disables profiles" do
            given_cucumber_yml_defined_as({'default' => '-v --require file_specified_in_default_profile.rb'})

            config.parse!("#{flag} --require some_file.rb".split(" "))

            expect(config.options[:require]).to eq ['some_file.rb']
          end

          it "notifies the user that the profiles are being disabled" do
            given_cucumber_yml_defined_as({'default' => '-v'})

            config.parse!("#{flag} --require some_file.rb".split(" "))

            expect(out.string).to match /Disabling profiles.../
          end
        end
      end

      it "issues a helpful error message when a specified profile exists but is nil or blank" do
        [nil, '   '].each do |bad_input|
          given_cucumber_yml_defined_as({'foo' => bad_input})

          expected_error = /The 'foo' profile in cucumber.yml was blank.  Please define the command line arguments for the 'foo' profile in cucumber.yml./

          expect(-> { config.parse!(%w{--profile foo}) }).to raise_error(expected_error)
        end
      end

      it "issues a helpful error message when no YAML file exists and a profile is specified" do
        expect(File).to receive(:exist?).with('cucumber.yml') { false }

        expected_error = /cucumber\.yml was not found/

        expect(-> { config.parse!(%w{--profile i_do_not_exist}) }).to raise_error(expected_error)
      end

      it "issues a helpful error message when cucumber.yml is blank or malformed" do
          expected_error_message = /cucumber\.yml was found, but was blank or malformed. Please refer to cucumber's documentation on correct profile usage./

        ['', 'sfsadfs', "--- \n- an\n- array\n", "---dddfd"].each do |bad_input|
          given_cucumber_yml_defined_as(bad_input)

          expect(-> { config.parse!([]) }).to raise_error(expected_error_message)

          reset_config
        end
      end

      it "issues a helpful error message when cucumber.yml can not be parsed" do
        expected_error_message = /cucumber.yml was found, but could not be parsed. Please refer to cucumber's documentation on correct profile usage./

        given_cucumber_yml_defined_as("input that causes an exception in YAML loading")

        expect(YAML).to receive(:load).and_raise(ArgumentError)
        expect(-> { config.parse!([]) }).to raise_error(expected_error_message)
      end

      it "issues a helpful error message when cucumber.yml can not be parsed by ERB" do
        expected_error_message = /cucumber.yml was found, but could not be parsed with ERB.  Please refer to cucumber's documentation on correct profile usage./
        given_cucumber_yml_defined_as("<% this_fails %>")

        expect(-> { config.parse!([]) }).to raise_error(expected_error_message)
      end
    end

    it "accepts --dry-run option" do
      config.parse!(%w{--dry-run})

      expect(config.options[:dry_run]).to be true
    end
    
    it "implies --no-duration with --dry-run option" do
      config.parse!(%w{--dry-run})
      
      expect(config.options[:duration]).to be false
    end

    it "accepts --no-source option" do
      config.parse!(%w{--no-source})

      expect(config.options[:source]).to be false
    end

    it "accepts --no-snippets option" do
      config.parse!(%w{--no-snippets})

      expect(config.options[:snippets]).to be false
    end

    it "sets snippets and source and duration to false with --quiet option" do
      config.parse!(%w{--quiet})

      expect(config.options[:snippets]).to be false
      expect(config.options[:source]).to be false
      expect(config.options[:duration]).to be false
    end
    
    it "sets duration to false with --no-duration" do
      config.parse!(%w{--no-duration})
      
      expect(config.options[:duration]).to be false
    end

    it "accepts --verbose option" do
      config.parse!(%w{--verbose})

      expect(config.options[:verbose]).to be true
    end

    it "accepts --out option" do
      config.parse!(%w{--out jalla.txt})

      expect(config.formats).to eq [['pretty', 'jalla.txt']]
    end

    it "accepts multiple --out options" do
      config.parse!(%w{--format progress --out file1 --out file2})

      expect(config.formats).to eq [['progress', 'file2']]
    end

    it "accepts multiple --format options and put the STDOUT one first so progress is seen" do
      config.parse!(%w{--format pretty --out pretty.txt --format progress})

      expect(config.formats).to eq [['progress', out], ['pretty', 'pretty.txt']]
    end

    it "does not accept multiple --format options when both use implicit STDOUT" do
      expect(-> { config.parse!(%w{--format pretty --format progress}) }).to raise_error("All but one formatter must use --out, only one can print to each stream (or STDOUT)")
    end

    it "does not accept multiple --format options when both use implicit STDOUT (using profile with no formatters)" do
      given_cucumber_yml_defined_as({'default' => ['-q']})
      expect(-> { config.parse!(%w{--format pretty --format progress}) }).to raise_error("All but one formatter must use --out, only one can print to each stream (or STDOUT)")
    end

    it "accepts same --format options with implicit STDOUT, and keep only one" do
      config.parse!(%w{--format pretty --format pretty})

      expect(config.formats).to eq [["pretty", out]]
    end

    it "does not accept multiple --out streams pointing to the same place" do
      expect(-> { config.parse!(%w{--format pretty --out file1 --format progress --out file1}) }).to raise_error("All but one formatter must use --out, only one can print to each stream (or STDOUT)")
    end

    it "does not accept multiple --out streams pointing to the same place (one from profile, one from command line)" do
      given_cucumber_yml_defined_as({'default' => ['-f','progress', '--out', 'file1']})
      expect(-> { config.parse!(%w{--format pretty --out file1}) }).to raise_error("All but one formatter must use --out, only one can print to each stream (or STDOUT)")
    end

    it "associates --out to previous --format" do
      config.parse!(%w{--format progress --out file1 --format profile --out file2})

      expect(config.formats).to eq [["progress", "file1"], ["profile" ,"file2"]]
    end

    it "accepts same --format options with same --out streams and keep only one" do
      config.parse!(%w{--format html --out file --format pretty --format html --out file})

      expect(config.formats).to eq [["pretty", out], ["html", "file"]]
    end

    it "accepts same --format options with different --out streams" do
      config.parse!(%w{--format html --out file1 --format html --out file2})

      expect(config.formats).to eq [["html", "file1"], ["html", "file2"]]
    end

    it "accepts --color option" do
      expect(Cucumber::Term::ANSIColor).to receive(:coloring=).with(true)

      config.parse!(['--color'])
    end

    it "accepts --no-color option" do
      expect(Cucumber::Term::ANSIColor).to receive(:coloring=).with(false)

      config = Configuration.new(StringIO.new)
      config.parse!(['--no-color'])
    end

    describe "--backtrace" do
      before do
        Cucumber.use_full_backtrace = false
      end

      it "shows full backtrace when --backtrace is present" do
        Main.new(['--backtrace'])
        begin
          expect("x").to eq "y"
        rescue RSpec::Expectations::ExpectationNotMetError => e
          expect(e.backtrace[0]).not_to eq "#{__FILE__}:#{__LINE__ - 2}"
        end
      end

      after do
        Cucumber.use_full_backtrace = false
      end
    end

    it "accepts multiple --name options" do
      config.parse!(['--name', "User logs in", '--name', "User signs up"])

      expect(config.options[:name_regexps]).to include(/User logs in/)
      expect(config.options[:name_regexps]).to include(/User signs up/)
    end

    it "accepts multiple -n options" do
      config.parse!(['-n', "User logs in", '-n', "User signs up"])

      expect(config.options[:name_regexps]).to include(/User logs in/)
      expect(config.options[:name_regexps]).to include(/User signs up/)
    end

    it "should allow specifying environment variables on the command line" do
      config.parse!(["foo=bar"])

      expect(ENV["foo"]).to eq "bar"
      expect(config.paths).not_to include('foo=bar')
    end

    it "allows specifying environment variables in profiles" do
      given_cucumber_yml_defined_as({'selenium' => 'RAILS_ENV=selenium'})
      config.parse!(["--profile", "selenium"])

      expect(ENV["RAILS_ENV"]).to eq "selenium"
      expect(config.paths).not_to include('RAILS_ENV=selenium')
    end

    describe "#tag_expression" do
      include RSpec::WorkInProgress

      it "returns an empty expression when no tags are specified" do
        config.parse!([])

        expect(config.tag_expression).to be_empty
      end

      it "returns an expression when tags are specified" do
        config.parse!(['--tags','@foo'])

        expect(config.tag_expression).not_to be_empty
      end
    end

    describe '#tag_limits' do
      it "returns an empty hash when no limits are specified" do
        config.parse!([])

        expect(config.tag_limits).to eq({ })
      end

      it "returns a hash of limits when limits are specified" do
        config.parse!(['--tags','@foo:1'])

        expect(config.tag_limits).to eq({ "@foo" => 1 })
      end
    end

    describe "#dry_run?" do
      it "returns true when --dry-run was specified on in the arguments" do
        config.parse!(['--dry-run'])

        expect(config.dry_run?).to be true
      end

      it "returns true when --dry-run was specified in yaml file" do
        given_cucumber_yml_defined_as({'default' => '--dry-run'})
        config.parse!([])

        expect(config.dry_run?).to be true
      end

      it "returns false by default" do
        config.parse!([])

        expect(config.dry_run?).to be false
      end
    end

    describe "#snippet_type" do
      it "returns the snippet type when it was set" do
        config.parse!(["--snippet-type", "classic"])

        expect(config.snippet_type).to eq :classic
      end

      it "returns the snippet type when it was set with shorthand option" do
        config.parse!(["-I", "classic"])

        expect(config.snippet_type).to eq :classic
      end

      it "returns the default snippet type if it was not set" do
        config.parse!([])

        expect(config.snippet_type).to eq :regexp
      end
    end

    describe "#retry_attempts" do 
      it "returns the specified number of retries" do 
        config.parse!(['--retry=3'])
        expect(config.retry_attempts).to eql 3
      end
    end
  end
end
end
