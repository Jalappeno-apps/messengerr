module Messengerr
  class CLI
    # messengerr credentials setup|list|verify|delete [--purge]
    class CredentialsCommand
      def initialize(prompter:, credentials:)
        @prompter = prompter
        @credentials = credentials
      end

      def run(args)
        case args.first
        when "setup" then setup(args[1])
        when "list" then list
        when "verify" then verify(args[1])
        when "delete" then delete(purge: args.include?("--purge"))
        else
          @prompter.say("Usage: messengerr credentials setup|list|verify|delete [--purge]")
          1
        end
      end

      private

      def setup(key)
        integration = find(key) or return 1
        integration.setup_class.new(prompter: @prompter, credentials: @credentials).run ? 0 : 1
      end

      def list
        @prompter.say("Registered integrations:")
        Registry.all.each do |integration|
          state = @credentials.configured?(integration.integration_key) ? "configured" : "not configured"
          @prompter.say("  #{integration.integration_key} (#{integration.delivery_method}) — #{state}")
        end
        0
      end

      def verify(key)
        integration = find(key) or return 1
        creds = @credentials.read(integration.integration_key)
        unless creds
          @prompter.say("#{integration.integration_key} is not configured — run `messengerr credentials setup #{integration.integration_key}`")
          return 1
        end

        integration.new(creds).verify!
        @prompter.say("#{integration.integration_key} verified.")
        0
      rescue IntegrationError => e
        @prompter.say(e.message)
        1
      end

      def delete(purge:)
        target = purge ? "credentials file AND master key" : "credentials file"
        return 1 unless @prompter.confirm("Delete the #{target}?")

        purge ? @credentials.purge! : @credentials.delete_file!
        @prompter.say("Deleted.")
        0
      end

      def find(key)
        integration = key && Registry.find(key)
        unless integration
          @prompter.say("Unknown integration '#{key}'. Available: #{Registry.all.map(&:integration_key).join(', ')}")
          return nil
        end
        integration
      end
    end
  end
end
