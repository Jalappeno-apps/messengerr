module Messengerr
  module Setups
    class Postmark < Base
      def self.required_keys
        [ :server_token, :from ]
      end
    end
  end
end
