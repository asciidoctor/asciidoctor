# -*- encoding: utf-8 -*-
require 'cucumber/core/test/result'
require 'cucumber/core/test/duration_matcher'

module Cucumber::Core::Test
  describe Result do

    let(:visitor) { double('visitor') }
    let(:args)    { double('args')    }

    describe Result::Passed do
      subject(:result) { Result::Passed.new(duration) }
      let(:duration)   { Result::Duration.new(1 * 1000 * 1000) }

      it "describes itself to a visitor" do
        expect( visitor ).to receive(:passed).with(args)
        expect( visitor ).to receive(:duration).with(duration, args)
        result.describe_to(visitor, args)
      end

      it "converts to a string" do
        expect( result.to_s ).to eq "✓"
      end

      it "has a duration" do
        expect( result.duration ).to eq duration
      end

      it "requires the constructor argument" do
        expect { Result::Passed.new }.to raise_error(ArgumentError)
      end

      it "does nothing when appending the backtrace" do
        expect( result.with_appended_backtrace(double) ).to equal result
      end

      it "does nothing when filtering the backtrace" do
        expect( result.with_filtered_backtrace(double) ).to equal result
      end

      specify { expect( result.to_sym ).to eq :passed }

      specify { expect( result ).to     be_passed    }
      specify { expect( result ).not_to be_failed    }
      specify { expect( result ).not_to be_undefined }
      specify { expect( result ).not_to be_unknown   }
      specify { expect( result ).not_to be_skipped   }

      specify { expect( result ).to be_ok }
      specify { expect( result.ok?(false) ).to be_truthy }
      specify { expect( result.ok?(true) ).to be_truthy }
    end

    describe Result::Failed do
      subject(:result) { Result::Failed.new(duration, exception) }
      let(:duration)   { Result::Duration.new(1 * 1000 * 1000) }
      let(:exception)  { StandardError.new("error message") }

      it "describes itself to a visitor" do
        expect( visitor ).to receive(:failed).with(args)
        expect( visitor ).to receive(:duration).with(duration, args)
        expect( visitor ).to receive(:exception).with(exception, args)
        result.describe_to(visitor, args)
      end

      it "has a duration" do
        expect( result.duration ).to eq duration
      end

      it "requires both constructor arguments" do
        expect { Result::Failed.new }.to raise_error(ArgumentError)
        expect { Result::Failed.new(duration) }.to raise_error(ArgumentError)
      end

      it "does nothing if step has no backtrace line" do
        result.exception.set_backtrace("exception backtrace")
        step = "does not respond_to?(:backtrace_line)"

        expect( result.with_appended_backtrace(step).exception.backtrace ).to eq(["exception backtrace"])
      end

      it "appends the backtrace line of the step" do
        result.exception.set_backtrace("exception backtrace")
        step = double
        expect( step ).to receive(:backtrace_line).and_return("step_line")

        expect( result.with_appended_backtrace(step).exception.backtrace ).to eq(["exception backtrace", "step_line"])
      end

      it "apply filters to the exception" do
        filter_class = double
        filter = double
        filtered_exception = double
        expect( filter_class ).to receive(:new).with(result.exception).and_return(filter)
        expect( filter ).to receive(:exception).and_return(filtered_exception)

        expect( result.with_filtered_backtrace(filter_class).exception ).to equal filtered_exception
      end

      specify { expect( result.to_sym ).to eq :failed }

      specify { expect( result ).not_to be_passed    }
      specify { expect( result ).to     be_failed    }
      specify { expect( result ).not_to be_undefined }
      specify { expect( result ).not_to be_unknown   }
      specify { expect( result ).not_to be_skipped   }

      specify { expect( result ).to_not be_ok }
      specify { expect( result.ok?(false) ).to be_falsey }
      specify { expect( result.ok?(true) ).to be_falsey }
    end

    describe Result::Unknown do
      subject(:result) { Result::Unknown.new }

      it "doesn't describe itself to a visitor" do
        visitor = double('never receives anything')
        result.describe_to(visitor, args)
      end

      specify { expect( result.to_sym ).to eq :unknown }

      specify { expect( result ).not_to be_passed    }
      specify { expect( result ).not_to be_failed    }
      specify { expect( result ).not_to be_undefined }
      specify { expect( result ).to     be_unknown   }
      specify { expect( result ).not_to be_skipped   }
    end

    describe Result::Raisable do
      context "with or without backtrace" do
        subject(:result) { Result::Raisable.new }

        it "does nothing if step has no backtrace line" do
          step = "does not respond_to?(:backtrace_line)"

          expect( result.with_appended_backtrace(step).backtrace ).to eq(nil)
        end
      end

      context "without backtrace" do
        subject(:result) { Result::Raisable.new }

        it "set the backtrace to the backtrace line of the step" do
          step = double
          expect( step ).to receive(:backtrace_line).and_return("step_line")

          expect( result.with_appended_backtrace(step).backtrace ).to eq(["step_line"])
        end

        it "does nothing when filtering the backtrace" do
          expect( result.with_filtered_backtrace(double) ).to equal result
        end
      end

      context "with backtrace" do
        subject(:result) { Result::Raisable.new("message", 0, "backtrace") }

        it "appends the backtrace line of the step" do
          step = double
          expect( step ).to receive(:backtrace_line).and_return("step_line")

          expect( result.with_appended_backtrace(step).backtrace ).to eq(["backtrace", "step_line"])
        end

        it "apply filters to the backtrace" do
          filter_class = double
          filter = double
          filtered_result = double
          expect( filter_class ).to receive(:new).with(result.exception).and_return(filter)
          expect( filter ).to receive(:exception).and_return(filtered_result)

          expect( result.with_filtered_backtrace(filter_class) ).to equal filtered_result
        end
      end
    end

    describe Result::Undefined do
      subject(:result) { Result::Undefined.new }

      it "describes itself to a visitor" do
        expect( visitor ).to receive(:undefined).with(args)
        expect( visitor ).to receive(:duration).with(an_unknown_duration, args)
        result.describe_to(visitor, args)
      end

      specify { expect( result.to_sym ).to eq :undefined }

      specify { expect( result ).not_to be_passed    }
      specify { expect( result ).not_to be_failed    }
      specify { expect( result ).to     be_undefined }
      specify { expect( result ).not_to be_unknown   }
      specify { expect( result ).not_to be_skipped   }

      specify { expect( result ).to be_ok }
      specify { expect( result.ok?(false) ).to be_truthy }
      specify { expect( result.ok?(true) ).to be_falsey }
    end

    describe Result::Skipped do
      subject(:result) { Result::Skipped.new }

      it "describes itself to a visitor" do
        expect( visitor ).to receive(:skipped).with(args)
        expect( visitor ).to receive(:duration).with(an_unknown_duration, args)
        result.describe_to(visitor, args)
      end

      specify { expect( result.to_sym ).to eq :skipped }

      specify { expect( result ).not_to be_passed    }
      specify { expect( result ).not_to be_failed    }
      specify { expect( result ).not_to be_undefined }
      specify { expect( result ).not_to be_unknown   }
      specify { expect( result ).to     be_skipped   }

      specify { expect( result ).to be_ok }
      specify { expect( result.ok?(false) ).to be_truthy }
      specify { expect( result.ok?(true) ).to be_truthy }
    end

    describe Result::Pending do
      subject(:result) { Result::Pending.new }

      it "describes itself to a visitor" do
        expect( visitor ).to receive(:pending).with(result, args)
        expect( visitor ).to receive(:duration).with(an_unknown_duration, args)
        result.describe_to(visitor, args)
      end

      specify { expect( result.to_sym ).to eq :pending }

      specify { expect( result ).not_to be_passed    }
      specify { expect( result ).not_to be_failed    }
      specify { expect( result ).not_to be_undefined }
      specify { expect( result ).not_to be_unknown   }
      specify { expect( result ).not_to be_skipped   }
      specify { expect( result ).to     be_pending   }

      specify { expect( result ).to be_ok }
      specify { expect( result.ok?(false) ).to be_truthy }
      specify { expect( result.ok?(true) ).to be_falsey }
    end

    describe Result::Summary do
      let(:summary)   { Result::Summary.new }
      let(:failed)    { Result::Failed.new(Result::Duration.new(10), exception) }
      let(:passed)    { Result::Passed.new(Result::Duration.new(11)) }
      let(:skipped)   { Result::Skipped.new }
      let(:unknown)   { Result::Unknown.new }
      let(:undefined) { Result::Undefined.new }
      let(:exception) { StandardError.new }

      it "counts failed results" do
        failed.describe_to summary
        expect( summary.total_failed   ).to eq 1
        expect( summary.total(:failed) ).to eq 1
        expect( summary.total          ).to eq 1
      end

      it "counts passed results" do
        passed.describe_to summary
        expect( summary.total_passed   ).to eq 1
        expect( summary.total(:passed) ).to eq 1
        expect( summary.total          ).to eq 1
      end

      it "counts skipped results" do
        skipped.describe_to summary
        expect( summary.total_skipped   ).to eq 1
        expect( summary.total(:skipped) ).to eq 1
        expect( summary.total           ).to eq 1
      end

      it "counts undefined results" do
        undefined.describe_to summary
        expect( summary.total_undefined   ).to eq 1
        expect( summary.total(:undefined) ).to eq 1
        expect( summary.total             ).to eq 1
      end

      it "counts abitrary raisable results" do
        flickering = Class.new(Result::Raisable) do
          def describe_to(visitor, *args)
            visitor.flickering(*args)
          end
        end

        flickering.new.describe_to summary
        expect( summary.total_flickering   ).to eq 1
        expect( summary.total(:flickering) ).to eq 1
        expect( summary.total              ).to eq 1
      end

      it "returns zero for a status where no messges have been received" do
        expect( summary.total_passed   ).to eq 0
        expect( summary.total(:passed) ).to eq 0
        expect( summary.total_ponies   ).to eq 0
        expect( summary.total(:ponies) ).to eq 0
      end

      it "doesn't count unknown results" do
        unknown.describe_to summary
        expect( summary.total ).to eq 0
      end

      it "counts combinations" do
        [passed, passed, failed, skipped, undefined].each { |r| r.describe_to summary }
        expect( summary.total           ).to eq 5
        expect( summary.total_passed    ).to eq 2
        expect( summary.total_failed    ).to eq 1
        expect( summary.total_skipped   ).to eq 1
        expect( summary.total_undefined ).to eq 1
      end

      it "records durations" do
        [passed, failed].each { |r| r.describe_to summary }
        expect( summary.durations[0] ).to be_duration 11
        expect( summary.durations[1] ).to be_duration 10
      end

      it "records exceptions" do
        [passed, failed].each { |r| r.describe_to summary }
        expect( summary.exceptions ).to eq [exception]
      end
    end

    describe Result::Duration do
      subject(:duration) { Result::Duration.new(10) }

      it "#nanoseconds can be accessed in #tap" do
        expect( duration.tap { |duration| @duration = duration.nanoseconds } ).to eq duration
        expect( @duration ).to eq 10
      end
    end

    describe Result::UnknownDuration do
      subject(:duration) { Result::UnknownDuration.new }

      it "#tap does not execute the passed block" do
        expect( duration.tap { raise "tap executed block" } ).to eq duration
      end

      it "accessing #nanoseconds outside #tap block raises exception" do
        expect { duration.nanoseconds }.to raise_error(RuntimeError)
      end
    end
  end
end
