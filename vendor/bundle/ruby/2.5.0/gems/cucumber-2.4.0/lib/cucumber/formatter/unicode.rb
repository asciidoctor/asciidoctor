# Require this file if you need Unicode support.
# Tips for improvement - esp. ruby 1.9: http://www.ruby-forum.com/topic/184730
require 'cucumber/platform'
require 'cucumber/formatter/ansicolor'

if Cucumber::WINDOWS
  if ENV['CUCUMBER_OUTPUT_ENCODING']
    Cucumber::CODEPAGE = ENV['CUCUMBER_OUTPUT_ENCODING']
  elsif `cmd /c chcp` =~ /(\d+)/
    if [65000, 65001].include? $1.to_i
      Cucumber::CODEPAGE = 'UTF-8'
      ENV['ANSICON_API'] = 'ruby'
    else
      Cucumber::CODEPAGE = "cp#{$1.to_i}"
    end
  else
    Cucumber::CODEPAGE = "cp1252"
    STDERR.puts("WARNING: Couldn't detect your output codepage. Assuming it is 1252. You may have to chcp 1252 or SET CUCUMBER_OUTPUT_ENCODING=cp1252.")
  end

  module Cucumber
    # @private
    module WindowsOutput
      def self.extended(o)
        o.instance_eval do

          def cucumber_preprocess_output(*a)
            begin
              a.map{|arg| arg.to_s.encode(Encoding.default_external)}
            rescue Encoding::UndefinedConversionError => e
              STDERR.cucumber_puts("WARNING: #{e.message}")
              a
            end
          end

          alias cucumber_print print
          def print(*a)
            cucumber_print(*cucumber_preprocess_output(*a))
          end

          alias cucumber_puts puts
          def puts(*a)
            cucumber_puts(*cucumber_preprocess_output(*a))
          end
        end
      end

      Kernel.extend(self)
      STDOUT.extend(self)
      STDERR.extend(self)
    end
  end
end
