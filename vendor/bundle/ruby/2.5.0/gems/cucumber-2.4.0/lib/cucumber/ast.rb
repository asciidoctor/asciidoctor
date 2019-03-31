require 'cucumber/multiline_argument'

module Cucumber
  module Ast
    def self.const_missing(const_name)
      if const_name == :Table
        warn "`Cucumber::Ast::Table` has been deprecated. Use `Cucumber::MultilineArgument::DataTable` instead."
        return Cucumber::MultilineArgument::DataTable
      end
      raise "`Cucumber::Ast` no longer exists. These classes have moved into the `Cucumber::Core::Ast` namespace, but may not have the same API."
    end
  end
end
