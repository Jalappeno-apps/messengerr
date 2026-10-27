require "net/http"
require "json"
require "uri"

module Messengerr
  module Integrations
    # ClickSend — SMS delivery via the v3 REST API using basic auth
    # (username + api_key). No SDK dependency.
    class ClickSend < Base
      API_URL = "https://rest.clicksend.com/v3"

      def self.delivery_method
        :sms
      end

      def send_batch(deliveries, options)
        body = {
          messages: deliveries.map { |delivery|
            { to: delivery.recipient.contact, body: delivery.body }.tap do |m|
              m[:from] = options.from || @credentials["from"] if options.from || @credentials["from"]
              m[:schedule] = options.schedule if options.schedule
            end
          }
        }
        response = post("/sms/send", body)
        results = response.dig("data", "messages") || []
        deliveries.each_with_index.map do |delivery, index|
          entry = results[index]
          if entry && %w[SUCCESS QUEUED].include?(entry["status"])
            Result.new(recipient: delivery.recipient, status: :sent, provider_id: entry["message_id"])
          else
            Result.new(recipient: delivery.recipient, status: :failed,
                       reason: entry ? entry["status"] : "no status returned",
                       uncertain: entry.nil?)
          end
        end
      rescue IntegrationError => e
        uncertain = e.is_a?(UncertainError)
        deliveries.map { |d| Result.new(recipient: d.recipient, status: :failed, reason: e.message, uncertain:) }
      end

      def verify!
        response = request(:get, "/account")
        raise IntegrationError, "ClickSend verification failed (#{response.code})" unless response.is_a?(Net::HTTPSuccess)

        true
      rescue IntegrationError
        raise
      rescue StandardError => e
        raise IntegrationError, "ClickSend unreachable: #{e.message}"
      end

      private

      def post(path, payload)
        response = request(:post, path, payload)
        unless response.is_a?(Net::HTTPSuccess)
          # 4xx = definitively rejected. 5xx (incl. gateway 502/504) can happen
          # after the batch was queued, so the outcome is unknown.
          error = response.code.to_i >= 500 ? UncertainError : IntegrationError
          raise error, "ClickSend rejected the request (#{response.code}): #{response.body.to_s[0, 200]}"
        end

        JSON.parse(response.body)
      rescue JSON::ParserError
        raise UncertainError, "ClickSend returned an unreadable response (#{response.code}) — status unknown"
      end

      def request(verb, path, payload = nil)
        uri = URI("#{API_URL}#{path}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = 5
        http.read_timeout = 10

        request = verb == :get ? Net::HTTP::Get.new(uri) : Net::HTTP::Post.new(uri)
        request.basic_auth(@credentials["username"], @credentials["api_key"])
        if payload
          request["Content-Type"] = "application/json"
          request.body = JSON.dump(payload)
        end
        http.request(request)
      rescue Net::OpenTimeout, Errno::ECONNREFUSED, SocketError, OpenSSL::SSL::SSLError => e
        # Failed before the request reached ClickSend: definitely not sent.
        raise IntegrationError, "ClickSend unreachable: #{e.message}"
      rescue Net::ReadTimeout, Net::WriteTimeout, Errno::ECONNRESET, Errno::EPIPE, EOFError => e
        # The request may have been processed before the connection died.
        raise UncertainError, "ClickSend connection lost mid-request (status unknown): #{e.message}"
      end
    end
  end
end
