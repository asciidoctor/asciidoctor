# undef_method wasn't public until 2.5
Dir.singleton_class.send :undef_method, :home
