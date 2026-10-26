module Messengerr
  # Extracts {{placeholder}} names from message text.
  module Placeholder
    PATTERN = /\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/

    def self.extract(text)
      text.to_s.scan(PATTERN).flatten.uniq
    end
  end
end
