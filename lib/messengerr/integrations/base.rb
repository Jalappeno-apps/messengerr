module Messengerr
  module Integrations
    # Contract every delivery integration implements. Instances are built with
    # the integration's decrypted credentials hash.
    class Base
      # :email or :sms — declared by the integration, not encoded in the namespace.
      def self.delivery_method
        raise NotImplementedError, "#{name} must declare .delivery_method"
      end

      # Body formats this integration can send: :text, and :html if it
      # delivers HTML. The CLI refuses --html for an integration that doesn't
      # list :html, so markup is never sent as plain text by mistake.
      def self.formats
        [ :text ]
      end

      def self.integration_key
        name.split("::").last.downcase.to_sym
      end

      # Parallel namespaces resolved by convention; override to wire explicitly.
      def self.setup_class
        Messengerr::Setups.const_get(class_name, false)
      end

      def self.options_class
        Messengerr::SendingOptions.const_get(class_name, false)
      end

      def self.class_name
        name.split("::").last
      end

      def self.inherited(subclass)
        super
        Registry.register(subclass) if subclass.name
      end

      def initialize(credentials)
        @credentials = credentials
      end

      # Send each Delivery (recipient + rendered body + optional subject).
      # → Array of Result, one per delivery — exactly one per recipient.
      # Integrations that send one by one should `yield` each Result as it lands
      # (optional block) so the ledger survives a crash mid-batch. Mark a failure
      # `uncertain: true` unless the provider definitely rejected it.
      def send_batch(deliveries, options)
        raise NotImplementedError, "#{self.class.name} must implement #send_batch"
      end

      # Cheap live call proving the credentials work; raise IntegrationError on failure.
      def verify!
        raise NotImplementedError, "#{self.class.name} must implement #verify!"
      end
    end
  end
end
