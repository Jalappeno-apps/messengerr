module Messengerr
  module Setups
    # Interactive credential setup for an integration. The subclass declares
    # which keys it needs; this framework prompts for them, runs the
    # integration's live verify!, and writes the values into the encrypted
    # credentials store.
    class Base
      # Keys the user must supply, e.g. [:server_token]. Optional keys go in
      # .optional_keys and may be left blank.
      def self.required_keys
        []
      end

      def self.optional_keys
        []
      end

      # The integration class this setup belongs to — inferred by convention.
      def self.integration_class
        Messengerr::Integrations.const_get(name.split("::").last)
      end

      def initialize(integration_class: self.class.integration_class,
                     prompter: Prompter.new,
                     credentials: Credentials.new)
        @integration_class = integration_class
        @prompter = prompter
        @credentials = credentials
      end

      # Returns true when credentials were verified and stored.
      def run
        @prompter.say("Setting up #{@integration_class.integration_key} (#{@integration_class.delivery_method}):")
        values = collect_values
        return false if values.nil?

        if verified?(values)
          @credentials.write(@integration_class.integration_key, values)
          @prompter.say("#{integration_label} is configured and verified.")
          true
        else
          @prompter.confirm("Try again?") ? run : false
        end
      end

      private

      def collect_values
        values = {}

        self.class.required_keys.each do |key|
          values[key] = @prompter.secret("#{key.to_s.tr('_', ' ')}:").to_s.strip
        end
        if values.values.any?(&:empty?)
          @prompter.say("All required fields must have a value — aborting.")
          return nil
        end

        self.class.optional_keys.each do |key|
          value = @prompter.ask("#{key.to_s.tr('_', ' ')} (optional, enter to skip):").to_s.strip
          values[key] = value unless value.empty?
        end

        values.transform_keys(&:to_s)
      end

      def verified?(values)
        @integration_class.new(values).verify!
        true
      rescue IntegrationError => e
        @prompter.say("Verification failed: #{e.message}")
        false
      end

      def integration_label
        @integration_class.integration_key.to_s.capitalize
      end
    end
  end
end
