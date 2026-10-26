module Messengerr
  class CLI
    # messengerr integrations — registry listing by delivery method.
    class IntegrationsCommand
      def initialize(prompter:, credentials:)
        @prompter = prompter
        @credentials = credentials
      end

      def run
        %i[email sms].each do |method|
          @prompter.say("#{method}:")
          integrations = Registry.by_method(method)
          if integrations.empty?
            @prompter.say("  (none registered)")
          else
            integrations.each do |integration|
              state = @credentials.configured?(integration.integration_key) ? "configured" : "not configured"
              @prompter.say("  #{integration.integration_key} — #{state}")
            end
          end
        end
        0
      end
    end
  end
end
