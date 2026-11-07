# frozen_string_literal: true

begin
  require 'ffi-icu'
rescue LoadError # rubocop:disable Lint/SuppressedException
end unless defined? ICU

module Asciidoctor
  class IndexCatalog
    LeadingAlphaRx = /^\p{Alpha}/
    CategoryNameTransliterationIDs = 'Any-Latin;Latin-ASCII;Any-Upper'

    def initialize locale = nil
      @categories = {}
      @dests = {}
      @locale = locale || 'en'
      @sequence = 0
    end

    def next_anchor_name
      %(_indexterm_#{@sequence += 1})
    end

    def create_dest parent
      IndexDestination.new next_anchor_name, parent
    end

    def store_term names, dest, assoc = {}
      if !(::Array === names)
        store_primary_term names, dest, assoc
      elsif (num_terms = names.size) == 1
        store_primary_term names[0], dest, assoc
      elsif num_terms == 2
        store_secondary_term names[0], names[1], dest, assoc
      elsif num_terms > 2
        store_tertiary_term names[0], names[1], names[2], dest, assoc
      end
    end

    def store_primary_term name, dest = nil, assoc = {}
      (init_category name).store_term name, dest, assoc
    end

    def store_secondary_term primary_name, secondary_name, dest = nil, assoc = {}
      (store_primary_term primary_name).store_term secondary_name, dest, assoc
    end

    def store_tertiary_term primary_name, secondary_name, tertiary_name, dest, assoc = {}
      (store_secondary_term primary_name, secondary_name).store_term tertiary_name, dest, assoc
    end

    def init_category term
      if LeadingAlphaRx.match? term
        name = term.chr
        name = !(defined? ::ICU::Transliteration) || name.ascii_only? ?
          name.upcase :
          ((::ICU::Transliteration::Transliterator.new CategoryNameTransliterationIDs).transliterate name)
      else
        name = '@'
      end
      @categories[name] ||= (IndexTermCategory.new name, @locale)
    end

    def find_category name
      @categories[name]
    end

    def find_primary_term name
      @categories.each_value do |category|
        term = category.terms.find {|candidate| candidate.name == name }
        return term if term
      end
      nil
    end

    def link_associations group = nil
      if group
        group.terms.each do |term|
          associations = term.associations
          if (see_name = associations[:see])
            term.see = (find_primary_term see_name) || (UnresolvedIndexTerm.new see_name)
          elsif (see_also_names = associations[:see_also])
            term.see_also = see_also_names.map do |see_also_name|
              (find_primary_term see_also_name) || (UnresolvedIndexTerm.new see_also_name)
            end
          end
          link_associations term unless term.leaf?
        end
      else
        @categories.each_value {|category| link_associations category }
      end
    end

    def empty?
      @categories.empty?
    end

    def categories
      @categories.empty? ? [] : @categories.values.sort
    end
  end

  class IndexDestination
    attr_reader :id
    attr_reader :section

    def initialize id, parent
      @id = id
      node = parent
      while (node = node.parent) && !(Section === node); end
      @section = node || parent.document
    end
  end

  class IndexTermGroup
    include Comparable
    attr_reader :name

    def initialize name, locale = nil
      @name = name
      @locale = locale || 'en'
      @terms = {}
    end

    def store_term name, dest = nil, assoc = {}
      term = (@terms[name] ||= (IndexTerm.new name, @locale))
      term.add_dest dest if dest
      term.associations ||= {}
      unless assoc.nil_or_empty?
        if !term.associations[:see] && (see = assoc[:see])
          term.associations[:see] = see
        end
        if (see_also = assoc[:see_also])
          (term.associations[:see_also] ||= []).concat see_also
        end
      end
      term
    end

    def find_term name
      @terms[name]
    end

    def terms
      @terms.empty? ? [] : @terms.values.sort
    end

    def <=> other
      if IndexTermCategory === self
        @name <=> other.name
      elsif (verdict = @name.casecmp other.name) == 0
        other.name <=> @name
      elsif (defined? ::ICU::Collation) && (!@name.ascii_only? || !other.name.ascii_only?)
        (::ICU::Collation::Collator.new @locale).compare @name, other.name
      else
        verdict
      end
    end
  end

  class IndexTermCategory < IndexTermGroup; end

  class UnresolvedIndexTerm < IndexTermGroup; end

  class IndexTerm < IndexTermGroup
    attr_accessor :associations

    attr_accessor :see

    attr_writer :see_also

    def initialize name, locale = nil
      super
      @dests = ::Set.new
      @associations = @see = @see_also = nil
    end

    alias subterms terms

    def add_dest dest
      @dests << dest
      self
    end

    def dests
      @dests.dup
    end

    def dests_by_section
      @dests.group_by {|dest| dest.section }
    end

    def container?
      @dests.empty?
    end

    def leaf?
      @terms.empty?
    end

    def see_also
      @see_also&.sort
    end
  end
end
