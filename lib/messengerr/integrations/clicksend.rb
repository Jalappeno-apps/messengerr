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

      def send_batch(pairs, options)
        body = {
          messages: pairs.map { |recipient, message|
            { to: recipient.contact, body: message }.tap do |m|
              m[:from] = options.from || @credentials["from"] if options.from || @credentials["from"]
              m[:schedule] = options.schedule if options.schedule
            end
          }
        }
        response = post("/sms/send", body)
        results = response.dig("data", "messages") || []
        pairs.each_with_index.map do |(recipient, _), index|
          entry = results[index]
          if entry && %w[SUCCESS QUEUED].include?(entry["status"])
            Result.new(recipient:, status: :sent, provider_id: entry["message_id"])
          else
            Result.new(recipient:, status: :failed,
                       reason: entry ? entry["status"] : "no status returned")
          end
        end
      rescue IntegrationError => e
        pairs.map { |recipient, _| Result.new(recipient:, status: :failed, reason: e.message) }
      end

      def verify!
        response = request(:get, "/account")
        raise IntegrationError, "ClickSend verification failed (#{response.code})" unless response.is_a?(Net::HTTPSuccess)

        true
      rescue Errno::ECONNREFUSED, SocketError, Net::OpenTimeout, Net::ReadTimeout => e
        raise IntegrationError, "ClickSend unreachable: #{e.message}"
      end

      private

      def post(path, payload)
        response = request(:post, path, payload)
        raise IntegrationError, "ClickSend rejected the request (#{response.code}): #{response.body[0, 200]}" unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body)
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
      end
    end
  end
end
