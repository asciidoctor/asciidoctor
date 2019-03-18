module Asciidoctor
  class IndexCatalog
    LeadingAlphaRx = /^\p{Alpha}/
  
    def initialize
      @categories = {}
      @counter = 0
    end
  
    def store_term parent, names
      dest = IndexDestination.new %(_indexterm_#{@counter += 1}), parent
      if (num_terms = names.size) > 2
        store_tertiary_term names[0], names[1], names[2], dest
      elsif num_terms == 2
        store_secondary_term names[0], names[1], dest
      elsif num_terms == 1
        store_primary_term names[0], dest
      end
      dest.id
    end
  
    def store_primary_term name, dest = nil
      (init_category name.chr.upcase).store_term name, dest
    end
  
    def store_secondary_term primary_name, secondary_name, dest = nil
      store_primary_term secondary_name, dest
      (store_primary_term primary_name).store_term secondary_name, dest
    end
  
    def store_tertiary_term primary_name, secondary_name, tertiary_name, dest = nil
      store_secondary_term secondary_name, tertiary_name, dest
      (store_secondary_term primary_name, secondary_name).store_term tertiary_name, dest
    end
  
    def init_category name
      name = '@' unless LeadingAlphaRx.match? name
      @categories[name] ||= IndexTermCategory.new name
    end
  
    def find_category name
      @categories[name]
    end
  
    def empty?
      @categories.empty?
    end
  
    def categories
      @categories.empty? ? [] : @categories.values.sort
    end
  end
  
  class IndexDestination
    attr_reader :id, :parent
  
    def initialize id, parent
      @id = id
      @parent = parent
    end
  
    def xref
      ref = self
      while (ref = ref.parent) && !(Section === ref); end
      ref || parent.document
    end
  
    def xreftext
      xref.xreftext
    end
  end
  
  class IndexTermGroup
    include Comparable
    attr_reader :name
  
    def initialize name
      @name = name 
      @terms = {}
    end
  
    def store_term name, dest = nil
      term = (@terms[name] ||= IndexTerm.new name)
      term.append_dest dest if dest
      term
    end
  
    def find_term name
      @terms[name]
    end
  
    def terms
      @terms.empty? ? [] : @terms.values.sort
    end
  
    def <=> other
      @name <=> other.name
    end
  end
  
  class IndexTermCategory < IndexTermGroup; end
  
  class IndexTerm < IndexTermGroup
    def initialize name
      super
      @dests = ::Set.new
    end
  
    alias subterms terms
  
    def append_dest dest
      @dests << dest
      self
    end
  
    def dests
      @dests.dup
    end
  
    def container?
      @dests.empty?
    end
  
    def leaf?
      @terms.empty?
    end
  end
end
