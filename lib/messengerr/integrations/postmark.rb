module Messengerr
  module Integrations
    # Postmark — email delivery via the postmark gem (lazy-loaded).
    class Postmark < Base
      def self.delivery_method
        :email
      end

      def send_batch(pairs, options)
        pairs.map do |recipient, body|
          deliver(recipient, body, options)
        end
      end

      def verify!
        client.server_info
        true
      rescue LoadError
        raise
      rescue StandardError => e
        raise IntegrationError, "Postmark verification failed: #{e.message}"
      end

      private

      def deliver(recipient, body, options)
        response = client.deliver(
          {
            from: options.from || @credentials["from"],
            to: recipient.contact,
            subject: options.subject,
            text_body: body,
            message_stream: options.message_stream,
            tag: options.tag,
            track_opens: options.track_opens
          }.compact
        )
        Result.new(recipient:, status: :sent, provider_id: response[:message_id])
      rescue StandardError => e
        Result.new(recipient:, status: :failed, reason: e.message)
      end

      def client
        @client ||= begin
          require "postmark"
          ::Postmark::ApiClient.new(@credentials["server_token"])
        rescue LoadError
          raise IntegrationError,
                "the postmark integration requires the 'postmark' gem — add it to your Gemfile or `gem install postmark`"
        end
      end
    end
  end
end
