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

      def self.options_class
        SendingOptions::Base
      end

      def initialize(credentials)
        @credentials = credentials
      end

      def verify!
        raise IntegrationError, "bad token" if @credentials["token"] == "bad"

        true
      end

      def send_batch(deliveries, options)
        deliveries.map do |delivery|
          recipient = delivery.recipient
          if recipient.row["fail"] == "yes"
            Result.new(recipient:, status: :failed, reason: "fake send failure")
          else
            Result.new(recipient:, status: :sent, provider_id: "fake-#{recipient.row_number}")
          end
        end
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
