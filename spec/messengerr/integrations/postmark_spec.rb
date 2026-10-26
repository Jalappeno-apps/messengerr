require "postmark"

RSpec.describe Messengerr::Integrations::Postmark do
  let(:integration) { described_class.new("server_token" => "tok", "from" => "me@x.com") }
  let(:recipient) { Messengerr::Recipient.new(contact: "you@y.com", row: {}, row_number: 2) }
  let(:options) { Messengerr::SendingOptions::Postmark.new(subject: "Hello") }

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
    it "delivers each pair and returns sent Results" do
      stub = stub_request(:post, "https://api.postmarkapp.com/email")
             .to_return(status: 200, body: '{"MessageID":"abc-123","ErrorCode":0}')
      results = integration.send_batch([[recipient, "Hi there"]], options)

      expect(results.first).to be_sent
      expect(results.first.provider_id).to eq("abc-123")
      expect(stub).to have_been_requested
    end

    it "returns a failed Result when the API rejects a message" do
      stub_request(:post, "https://api.postmarkapp.com/email")
        .to_return(status: 422, body: '{"ErrorCode":300,"Message":"Invalid email"}')
      results = integration.send_batch([[recipient, "Hi"]], options)

      expect(results.first.status).to eq(:failed)
      expect(results.first.reason).to eq("Invalid email")
    end
  end
end
