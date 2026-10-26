module Messengerr
  # Substitutes {{placeholder}} tokens with values from a CSV row, using a
  # user-supplied mapping of placeholder name → column name.
  module Renderer
    def self.render(template, row, mapping)
      template.gsub(Placeholder::PATTERN) do
        key = Regexp.last_match(1)
        column = mapping[key]
        raise RenderError, "no column mapped for placeholder {{#{key}}}" if column.nil?

        value = row[column]
        raise RenderError, "column \"#{column}\" is empty for {{#{key}}}" if value.nil? || value.strip.empty?

        value.strip
      end
    end
  end
end
