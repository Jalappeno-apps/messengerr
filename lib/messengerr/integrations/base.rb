module Messengerr
  module Integrations
    # Contract every delivery integration implements. Instances are built with
    # the integration's decrypted credentials hash.
    class Base
      # :email or :sms — declared by the integration, not encoded in the namespace.
      def self.delivery_method
        raise NotImplementedError, "#{name} must declare .delivery_method"
      end

      def self.integration_key
        name.split("::").last.downcase.to_sym
      end

      # Parallel namespaces resolved by convention; override to wire explicitly.
      def self.setup_class
        Messengerr::Setups.const_get(integration_key.to_s.capitalize)
      end

      def self.options_class
        Messengerr::SendingOptions.const_get(integration_key.to_s.capitalize)
      end

      def self.inherited(subclass)
        super
        Registry.register(subclass) if subclass.name
      end

      def initialize(credentials)
        @credentials = credentials
      end

      # Send `message` (rendered text) to each recipient.
      # → Array of Result, one per recipient.
      def send_batch(recipients, message, options)
        raise NotImplementedError, "#{self.class.name} must implement #send_batch"
      end

      # Cheap live call proving the credentials work; raise IntegrationError on failure.
      def verify!
        raise NotImplementedError, "#{self.class.name} must implement #verify!"
      end
    end
  end
end
