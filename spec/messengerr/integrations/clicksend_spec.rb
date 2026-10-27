RSpec.describe Messengerr::Integrations::ClickSend do
  let(:integration) { described_class.new("username" => "u", "api_key" => "k") }
  let(:recipient) { Messengerr::Recipient.new(contact: "+12025550123", row: {}, row_number: 2) }
  let(:options) { Messengerr::SendingOptions::ClickSend.new }

  describe ".delivery_method" do
    it { expect(described_class.delivery_method).to eq(:sms) }
    it { expect(described_class.integration_key).to eq(:clicksend) }
    it { expect(described_class.setup_class).to eq(Messengerr::Setups::ClickSend) }
    it { expect(described_class.options_class).to eq(Messengerr::SendingOptions::ClickSend) }
  end

  describe "#verify!" do
    it "succeeds on valid credentials" do
      stub_request(:get, "https://rest.clicksend.com/v3/account")
        .to_return(status: 200, body: "{}")
      expect(integration.verify!).to be(true)
    end

    it "raises IntegrationError on bad credentials" do
      stub_request(:get, "https://rest.clicksend.com/v3/account")
        .to_return(status: 401, body: "{}")
      expect { integration.verify! }.to raise_error(Messengerr::IntegrationError)
    end
  end

  describe "#send_batch" do
    it "posts messages with basic auth and maps statuses to Results" do
      stub = stub_request(:post, "https://rest.clicksend.com/v3/sms/send")
             .with(basic_auth: %w[u k])
             .to_return(status: 200, body: {
               data: { messages: [
                 { message_id: "m1", status: "SUCCESS" },
                 { message_id: "m2", status: "INVALID_RECIPIENT" }
               ] }
             }.to_json)

      deliveries = [
        Messengerr::Delivery.new(recipient:, body: "Hi", subject: nil),
        Messengerr::Delivery.new(
          recipient: Messengerr::Recipient.new(contact: "+12025550999", row: {}, row_number: 3),
          body: "Hi", subject: nil
        )
      ]
      results = integration.send_batch(deliveries, options)

      expect(results.map(&:status)).to eq(%i[sent failed])
      expect(results.first.provider_id).to eq("m1")
      expect(results.last.reason).to eq("INVALID_RECIPIENT")
      expect(stub).to have_been_requested
    end

    it "fails the whole batch when the API rejects the request" do
      stub_request(:post, "https://rest.clicksend.com/v3/sms/send")
        .to_return(status: 401, body: "{}")

      results = integration.send_batch([Messengerr::Delivery.new(recipient:, body: "Hi", subject: nil)], options)
      expect(results.first.status).to eq(:failed)
      expect(results.first.reason).to include("401")
      expect(results.first.uncertain).to be(false) # a 4xx is a definite rejection
    end

    describe "uncertain vs definite failures" do
      let(:deliveries) { [Messengerr::Delivery.new(recipient:, body: "Hi", subject: nil)] }
      let(:url) { "https://rest.clicksend.com/v3/sms/send" }

      def outcome(&stubbing)
        stubbing.call
        integration.send_batch(deliveries, options).first
      end

      it "treats 4xx (incl. 429) as definite" do
        [400, 401, 422, 429].each do |status|
          result = outcome { stub_request(:post, url).to_return(status:, body: "{}") }
          expect(result.uncertain).to be(false), "expected #{status} to be definite"
        end
      end

      it "treats 5xx, including gateway 502/504, as uncertain" do
        [500, 502, 503, 504].each do |status|
          result = outcome { stub_request(:post, url).to_return(status:, body: "gateway") }
          expect(result).to have_attributes(status: :failed, uncertain: true), "expected #{status} to be uncertain"
        end
      end

      it "treats a 200 with an unreadable body as uncertain" do
        result = outcome { stub_request(:post, url).to_return(status: 200, body: "<html>") }
        expect(result).to have_attributes(status: :failed, uncertain: true)
        expect(result.reason).to match(/unreadable/)
      end

      it "treats a read timeout (request already sent) as uncertain" do
        result = outcome { stub_request(:post, url).to_raise(Net::ReadTimeout) }
        expect(result).to have_attributes(status: :failed, uncertain: true)
      end

      it "treats a connection reset mid-request as uncertain" do
        result = outcome { stub_request(:post, url).to_raise(Errno::ECONNRESET) }
        expect(result.uncertain).to be(true)
      end

      it "treats failing to connect (nothing was sent) as definite" do
        [Net::OpenTimeout, Errno::ECONNREFUSED, SocketError, OpenSSL::SSL::SSLError].each do |error|
          result = outcome { stub_request(:post, url).to_raise(error) }
          expect(result).to have_attributes(status: :failed, uncertain: false), "expected #{error} to be definite"
        end
      end

      it "treats a missing per-message status as uncertain but an explicit rejection as definite" do
        stub_request(:post, url).to_return(status: 200, body: { data: { messages: [] } }.to_json)
        expect(integration.send_batch(deliveries, options).first.uncertain).to be(true)

        stub_request(:post, url).to_return(
          status: 200, body: { data: { messages: [{ message_id: "m", status: "INVALID_RECIPIENT" }] } }.to_json
        )
        expect(integration.send_batch(deliveries, options).first.uncertain).to be(false)
      end
    end
  end
end
