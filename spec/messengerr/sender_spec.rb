RSpec.describe Messengerr::Sender do
  let(:integration) { Messengerr::Integrations::Fake.new({}) }
  let(:rows) do
    [
      { "name" => "Alice", "email" => "a@x.com" },
      { "name" => "Bob", "email" => "b@x.com", "fail" => "yes" },
      { "name" => "", "email" => "c@x.com" }
    ]
  end
  let(:recipients) do
    rows.each_with_index.map { |row, i| Messengerr::Recipient.new(contact: row["email"], row:, row_number: i + 2) }
  end
  let(:mapping) { { "name" => "name" } }

  it "sends each recipient their rendered message" do
    sender = described_class.new(integration, options: options(batch_size: 10))
    results = sender.send(recipients, "Hi {{name}}", mapping)

    sent = results.select(&:sent?)
    expect(sent.length).to eq(1)
    expect(sent.first.provider_id).to eq("fake-2")
  end

  it "collects send failures with reasons" do
    sender = described_class.new(integration, options: options(batch_size: 10))
    results = sender.send(recipients, "Hi {{name}}", mapping)

    expect(results.map(&:reason).compact).to include("fake send failure")
  end

  it "collects render failures per row" do
    sender = described_class.new(integration, options: options(batch_size: 10))
    results = sender.send(recipients, "Hi {{name}}", mapping)

    render_failures = results.select { |r| r.reason.to_s.include?("empty") }
    expect(render_failures.length).to eq(1)
  end

  it "splits sends into batch_size slices" do
    calls = []
    spy = Class.new(Messengerr::Integrations::Fake) do
      define_method(:send_batch) do |pairs, _options|
        calls << pairs
        super(pairs, _options)
      end
    end.new({})

    sender = described_class.new(spy, options: options(batch_size: 1))
    sender.send(recipients, "Hi {{name}}", mapping)

    expect(calls.map(&:length)).to all(eq(1))
    expect(calls.length).to eq(2) # third row fails render, never sent
  end

  it "marks a whole batch failed when the integration raises" do
    failing = Class.new(Messengerr::Integrations::Fake) do
      def send_batch(_pairs, _options)
        raise Messengerr::IntegrationError, "provider down"
      end
    end.new({})

    sender = described_class.new(failing, options: options(batch_size: 10))
    results = sender.send(recipients.first(1), "Hi {{name}}", mapping)

    expect(results.first.status).to eq(:failed)
    expect(results.first.reason).to eq("provider down")
  end

  it "validates options on init" do
    expect { described_class.new(integration, options: options(batch_size: 0)) }
      .to raise_error(Messengerr::ValidationError)
  end

  def options(batch_size: 50)
    Messengerr::SendingOptions::Base.new(batch_size:, rate_limit: 1000)
  end
end
