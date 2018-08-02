require 'thread_safe'

module Concurrent
  Hash = ::ThreadSafe::Cache
end
