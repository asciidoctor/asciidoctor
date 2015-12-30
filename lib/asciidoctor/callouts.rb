# encoding: UTF-8
module Asciidoctor
# Public: Maintains a catalog of callouts and their associations.
class Callouts
  def initialize
    @lists = []
    @list_index = 0
    next_list
  end

  # Public: Register a new callout for the given list item ordinal.
  #
  # Generates a unique id for this callout based on the index of the next callout
  # list in the document and the index of this callout since the end of the last
  # callout list.
  #
  # li_ordinal - the Integer ordinal (1-based) of the list item to which this
  #              callout is to be associated
  #
  # Examples
  #
  #  callouts = Asciidoctor::Callouts.new
  #  callouts.register(1)
  #  # => "CO1-1"
  #  callouts.next_list
  #  callouts.register(2)
  #  # => "CO2-1"
  #
  # Returns The unique String id of this callout
  def register li_ordinal
    current_list << { :ordinal => li_ordinal.to_i, :id => (id = generate_next_callout_id) }
    @co_index += 1
    id
  end

  # Public: Get the next callout index in the document
  #
  # Reads the next callout index in the document and advances the pointer.
  # This method is used during conversion to retrieve the unique id of the
  # callout that was generated during parsing.
  #
  # Returns The unique String id of the next callout in the document
  def read_next_id
    id = nil
    list = current_list

    if @co_index <= list.size
      id = list[@co_index - 1][:id]
    end

    @co_index += 1
    id
  end

  # Public: Get a space-separated list of callout ids for the specified list item
  #
  # li_ordinal - the Integer ordinal (1-based) of the list item for which to
  #              retrieve the callouts
  #
  # Returns A space-separated String of callout ids associated with the specified list item
  def callout_ids li_ordinal
    current_list.map {|element| element[:ordinal] == li_ordinal ? %(#{element[:id]} ) : nil }.join.chop
  end

  # Public: The current list for which callouts are being collected
  #
  # Returns The Array of callouts at the position of the list index pointer
  def current_list
    @lists[@list_index - 1]
  end

  # Public: Advance to the next callout list in the document
  #
  # Returns nothing
  def next_list
    @list_index += 1

    if @lists.size < @list_index
      @lists << []
    end

    @co_index = 1
    nil
  end

  # Public: Rewind the list index pointer, intended to be used when switching
  # from the parsing to conversion phase.
  #
  # Returns nothing
  def rewind
    @list_index = 1
    @co_index = 1
    nil
  end

  # Internal: Generate a unique id for the callout based on the internal indexes
  #
  # Returns A unique String id for this callout
  def generate_next_callout_id
    generate_callout_id @list_index, @co_index
  end

  # Internal: Generate a unique id for the callout at the specified position
  #
  # list_index - The 1-based Integer index of the callout list within the document
  # co_index   - The 1-based Integer index of the callout since the end of the last callout list
  #
  # Returns A unique String id for a callout
  def generate_callout_id list_index, co_index
    %(CO#{list_index}-#{co_index})
  end
end
end
