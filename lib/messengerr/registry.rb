module Messengerr
  # Lookup table of registered integration classes. Built-in integrations
  # register themselves when Zeitwerk loads them; community gems call
  # Messengerr.register_integration on load.
  module Registry
    @integrations = []

    class << self
      def register(integration_class)
        @integrations << integration_class unless @integrations.include?(integration_class)
      end

      def all
        ensure_loaded
        @integrations.dup
      end

      def by_method(delivery_method)
        all.select { |i| i.delivery_method == delivery_method.to_sym }
      end

      def find(integration_key)
        all.find { |i| i.integration_key == integration_key.to_sym }
      end

      def configured(credentials = Credentials.new)
        all.select { |i| credentials.configured?(i.integration_key) }
      end

      def configured_by_method(delivery_method, credentials = Credentials.new)
        by_method(delivery_method).select { |i| credentials.configured?(i.integration_key) }
      end

      private

      # Touch the built-in integration constants so Zeitwerk loads (and registers) them.
      def ensure_loaded
        Integrations.constants.each { |c| Integrations.const_get(c) }
      end
    end
  end
end
