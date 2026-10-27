require "postmark"

RSpec.describe Messengerr::Integrations::Postmark do
  let(:integration) { described_class.new("server_token" => "tok", "from" => "me@x.com") }
  let(:recipient) { Messengerr::Recipient.new(contact: "you@y.com", row: {}, row_number: 2) }
  let(:options) { Messengerr::SendingOptions::Postmark.new }
  let(:delivery) { Messengerr::Delivery.new(recipient:, body: "Hi there", subject: "Hello") }

  describe ".delivery_method" do
    it { expect(described_class.delivery_method).to eq(:email) }
    it { expect(described_class.integration_key).to eq(:postmark) }
    it { expect(described_class.setup_class).to eq(Messengerr::Setups::Postmark) }
    it { expect(described_class.options_class).to eq(Messengerr::SendingOptions::Postmark) }
  end

  describe "#verify!" do
    it "succeeds on a valid token" do
      stub_request(:get, "https://api.postmarkapp.com/server")
        .to_return(status: 200, body: '{"Name":"prod"}')
      expect(integration.verify!).to be(true)
    end

    it "raises IntegrationError on a bad token" do
      stub_request(:get, "https://api.postmarkapp.com/server")
        .to_return(status: 401, body: '{"Message":"Unauthorized"}')
      expect { integration.verify! }.to raise_error(Messengerr::IntegrationError)
    end
  end

  describe "#send_batch" do
    it "delivers each Delivery with its own subject and returns sent Results" do
      stub = stub_request(:post, "https://api.postmarkapp.com/email")
             .to_return(status: 200, body: '{"MessageID":"abc-123","ErrorCode":0}')
      results = integration.send_batch([ delivery ], options)

      expect(results.first).to be_sent
      expect(results.first.provider_id).to eq("abc-123")
      expect(stub.with { |req| JSON.parse(req.body).values_at("Subject", "TextBody", "To") == [ "Hello", "Hi there", "you@y.com" ] })
        .to have_been_requested
    end

    it "returns a failed Result when the API rejects a message" do
      stub_request(:post, "https://api.postmarkapp.com/email")
        .to_return(status: 422, body: '{"ErrorCode":300,"Message":"Invalid email"}')
      results = integration.send_batch([ delivery ], options)

      expect(results.first.status).to eq(:failed)
      expect(results.first.reason).to eq("Invalid email")
      expect(results.first.uncertain).to be(false) # 422: definitely not accepted
    end

    describe "uncertain vs definite failures" do
      let(:url) { "https://api.postmarkapp.com/email" }

      def outcome = integration.send_batch([ delivery ], options).first

      it "treats 401 and 422 as definite" do
        [ 401, 422 ].each do |status|
          stub_request(:post, url).to_return(status:, body: '{"ErrorCode":300,"Message":"no"}')
          expect(outcome.uncertain).to be(false), "expected #{status} to be definite"
        end
      end

      it "treats a 500 as uncertain" do
        stub_request(:post, url).to_return(status: 500, body: "{}")
        expect(outcome).to have_attributes(status: :failed, uncertain: true)
      end

      it "treats a timeout as uncertain" do
        stub_request(:post, url).to_timeout
        expect(outcome).to have_attributes(status: :failed, uncertain: true)
      end

      it "treats a dropped connection as uncertain" do
        stub_request(:post, url).to_raise(Errno::ECONNRESET)
        expect(outcome.uncertain).to be(true)
      end
    end

    it "yields each Result as it is sent so the ledger can record it immediately" do
      stub_request(:post, "https://api.postmarkapp.com/email")
        .to_return(status: 200, body: '{"MessageID":"x","ErrorCode":0}')
      yielded = []
      integration.send_batch([ delivery, delivery ], options) { |r| yielded << r }

      expect(yielded.length).to eq(2)
    end

    it "fails a delivery that has no subject without calling the API" do
      stub = stub_request(:post, "https://api.postmarkapp.com/email")
      no_subject = Messengerr::Delivery.new(recipient:, body: "Hi", subject: nil)
      results = integration.send_batch([ no_subject ], options)

      expect(results.first.status).to eq(:failed)
      expect(results.first.reason).to match(/subject is required/)
      expect(stub).not_to have_been_requested
    end

    it "falls back to options.subject when the delivery has none" do
      stub = stub_request(:post, "https://api.postmarkapp.com/email")
             .to_return(status: 200, body: '{"MessageID":"x","ErrorCode":0}')
      fallback = Messengerr::SendingOptions::Postmark.new(subject: "Default")
      integration.send_batch([ Messengerr::Delivery.new(recipient:, body: "Hi", subject: nil) ], fallback)

      expect(stub.with { |req| JSON.parse(req.body)["Subject"] == "Default" }).to have_been_requested
    end
  end
end
