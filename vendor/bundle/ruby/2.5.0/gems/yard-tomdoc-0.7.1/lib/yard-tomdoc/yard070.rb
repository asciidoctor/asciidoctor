module YARD

  class Docstring
    def parse_comments(comments)
      comment = [comments].flatten.join("\n")
      tomdoc  = TomDoc.yard_parse(self, comment)
      tomdoc.description.to_s  # return the modified comment
    end

    public :create_tag
  end

end
