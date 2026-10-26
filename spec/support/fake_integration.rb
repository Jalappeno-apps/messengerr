module Messengerr
  module Integrations
    class Fake < Integrations::Base
      def self.delivery_method
        :email
      end

      def self.integration_key
        :fake
      end

      def self.setup_class
        Setups::Fake
      end

      def initialize(credentials)
        @credentials = credentials
      end

      def verify!
        raise IntegrationError, "bad token" if @credentials["token"] == "bad"

        true
      end

      def send_batch(recipients, message, options)
        recipients.map { Result.new(recipient: _1, status: :sent) }
      end
    end
  end

  module Setups
    class Fake < Setups::Base
      def self.required_keys
        [:token]
      end

      def self.optional_keys
        [:region]
      end

      def self.integration_class
        Integrations::Fake
      end
    end
  end
end
