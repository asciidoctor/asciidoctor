# frozen_string_literal: true
# NOTE remove once minimum required Ruby version is at least 2.6
Hash.prepend(Module.new do
  def merge *args
    (len = args.length) < 1 ? super({}) : (len > 1 ? args.inject(self) {|acc, arg| acc.merge arg } : (super args[0]))
  end
end) if (Hash.instance_method :merge).arity == 1
