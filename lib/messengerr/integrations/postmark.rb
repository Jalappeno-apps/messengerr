module Messengerr
  module Integrations
    # Postmark — email delivery via the postmark gem (lazy-loaded).
    class Postmark < Base
      def self.delivery_method
        :email
      end

      def self.formats
        [ :text, :html ]
      end

      def send_batch(deliveries, options)
        deliveries.map do |delivery|
          deliver_one(delivery, options).tap { |result| yield result if block_given? }
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

      def deliver_one(delivery, options)
        subject = delivery.subject || options.subject
        if subject.to_s.strip.empty?
          return Result.new(recipient: delivery.recipient, status: :failed, reason: "subject is required for email sends")
        end

        response = client.deliver(
          {
            from: options.from || @credentials["from"],
            to: delivery.recipient.contact,
            subject:,
            **body_params(delivery),
            message_stream: options.message_stream,
            tag: options.tag,
            track_opens: options.track_opens
          }.compact
        )
        Result.new(recipient: delivery.recipient, status: :sent, provider_id: response[:message_id])
      rescue StandardError => e
        Result.new(recipient: delivery.recipient, status: :failed, reason: e.message,
                   uncertain: !definitely_rejected?(e))
      end

      # Exactly one body: HTML mail is HTML only, text mail is text only.
      def body_params(delivery)
        delivery.html? ? { html_body: delivery.body } : { text_body: delivery.body }
      end

      # Only a 4xx from the API proves the message was not accepted. Timeouts,
      # connection errors, 5xx and anything unrecognised may have gone through.
      def definitely_rejected?(error)
        defined?(::Postmark::HttpServerError) &&
          error.is_a?(::Postmark::HttpServerError) &&
          (400..499).cover?(error.status_code)
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
