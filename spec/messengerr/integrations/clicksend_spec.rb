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

      pairs = [
        [recipient, "Hi"],
        [Messengerr::Recipient.new(contact: "+12025550999", row: {}, row_number: 3), "Hi"]
      ]
      results = integration.send_batch(pairs, options)

      expect(results.map(&:status)).to eq(%i[sent failed])
      expect(results.first.provider_id).to eq("m1")
      expect(results.last.reason).to eq("INVALID_RECIPIENT")
      expect(stub).to have_been_requested
    end

    it "fails the whole batch when the API rejects the request" do
      stub_request(:post, "https://rest.clicksend.com/v3/sms/send")
        .to_return(status: 401, body: "{}")

      results = integration.send_batch([[recipient, "Hi"]], options)
      expect(results.first.status).to eq(:failed)
      expect(results.first.reason).to include("401")
    end
  end
end
