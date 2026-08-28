# frozen_string_literal: true

module Asciidoctor
# Public: Stores index terms independently of how a converter presents them.
class IndexCatalog
  LeadingAlphaRx = /^\p{Alpha}/

  def initialize
    @categories = {}
    @anchors = {}
    @anchor_sequence = @term_sequence = 0
  end

  def next_anchor_name key = nil
    return @anchors[key] ||= next_anchor_name unless key.nil?
    %(__indexterm-#{@anchor_sequence += 1})
  end

  def store_term names, dest = nil, assoc = {}
    names = (::Array === names ? names : [names]).first(3).compact
    names.reject! {|name| IndexTermGroup.sort_key_for(name).empty? }
    return if names.empty?

    last_idx = names.length - 1
    group = init_category names[0]
    names.each_with_index do |name, idx|
      group = group.store_term name, (dest if idx == last_idx), (idx == last_idx ? assoc : {})
    end
    group
  end

  def find_primary_term name
    sort_key = IndexTermGroup.sort_key_for name
    @categories.each_value do |category|
      term = category.terms.find {|candidate| candidate.sort_key == sort_key }
      return term if term
    end
    nil
  end

  def link_associations group = nil
    if group
      group.terms.each do |term|
        if (see_name = term.associations[:see])
          term.see = (find_primary_term see_name) || (UnresolvedIndexTerm.new see_name)
        elsif (see_also_names = term.associations[:see_also])
          term.see_also = see_also_names.map {|name| (find_primary_term name) || (UnresolvedIndexTerm.new name) }
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
    @categories.values.sort
  end

  def next_term_anchor
    %(__indextermdef-#{@term_sequence += 1})
  end

  private

  def init_category term
    sort_key = IndexTermGroup.sort_key_for term
    name = LeadingAlphaRx.match?(sort_key) ? sort_key.chr.upcase : '@'
    @categories[name] ||= (IndexTermCategory.new name, self)
  end
end

# Public: A sortable group of index terms.
class IndexTermGroup
  include Comparable

  attr_reader :name
  attr_reader :sort_key

  def self.sort_key_for name
    name = name.to_s
    name = name.gsub(XmlSanitizeRx, '') if name.include? '<'
    name.squeeze(' ').strip
  end

  def initialize name, catalog = nil
    @name = name
    @sort_key = self.class.sort_key_for name
    @catalog = catalog
    @terms = {}
  end

  def store_term name, dest = nil, assoc = {}
    term = (@terms[name] ||= (IndexTerm.new name, @catalog))
    term.add_dest dest if dest
    if !term.associations[:see] && (see = assoc[:see])
      term.associations[:see] = see
    end
    if (see_also = assoc[:see_also])
      (term.associations[:see_also] ||= []).concat(see_also).uniq!
    end
    term
  end

  def terms
    @terms.empty? ? [] : @terms.values.sort
  end

  def <=> other
    return @name <=> other.name if IndexTermCategory === self
    if (verdict = @sort_key.casecmp other.sort_key) == 0
      (verdict = @sort_key <=> other.sort_key) == 0 ? (@name.to_s <=> other.name.to_s) : verdict
    else
      verdict
    end
  end
end

class IndexTermCategory < IndexTermGroup; end

class UnresolvedIndexTerm < IndexTermGroup; end

# Public: A term and its occurrences in an index catalog.
class IndexTerm < IndexTermGroup
  attr_reader :anchor
  attr_reader :associations
  attr_accessor :see
  attr_writer :see_also

  def initialize name, catalog
    super
    @anchor = catalog.next_term_anchor
    @dests = ::Set.new
    @associations = {}
  end

  alias subterms terms

  def add_dest dest
    @dests << dest
    self
  end

  def dests
    @dests.to_a
  end

  def leaf?
    @terms.empty?
  end

  def see_also
    @see_also&.sort
  end
end
end
