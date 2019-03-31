module TomParse

  # Encapsulate a named parameter.
  #
  class Option

    attr_accessor :name

    attr_accessor :description

    # Create new Argument object.
    #
    # name        - name of option
    # description - option description
    #
    def initialize(name, description = '')
      @name = name.to_s.intern
      @description = description
    end

    # Is this a required option?
    #
    # Returns Boolean.
    def required?
      @description.downcase.include? 'required'
    end

  end

end
