module Messengerr
  module Setups
    class ClickSend < Base
      def self.required_keys
        [:username, :api_key]
      end

      def self.optional_keys
        [:from]
      end
    end
  end
end
