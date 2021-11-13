# frozen_string_literal: true
# NOTE remove once minimum required Ruby version is at least 2.6
# NOTE use `send :prepend` to be nice to Ruby 2.0
Hash.send :prepend, (Module.new do
  def merge *args
    (len = args.length) < 1 ? dup : (len > 1 ? args.inject(self) {|acc, arg| acc.merge arg } : (super args[0]))
  end
end) if (Hash.instance_method :merge).arity == 1
