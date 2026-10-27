RSpec.describe Messengerr::Registry do
  it "registers integrations automatically on inheritance" do
    expect(described_class.all).to include(Messengerr::Integrations::Fake)
  end

  it "filters by delivery method" do
    email_integrations = described_class.by_method(:email)
    expect(email_integrations).to include(Messengerr::Integrations::Fake)
    expect(described_class.by_method(:sms)).not_to include(Messengerr::Integrations::Fake)
  end

  it "finds integrations by key" do
    expect(described_class.find(:fake)).to eq(Messengerr::Integrations::Fake)
    expect(described_class.find(:nope)).to be_nil
  end

  it "lists only configured integrations" do
    credentials = instance_double(Messengerr::Credentials)
    allow(credentials).to receive(:configured?).with(anything).and_return(false)
    allow(credentials).to receive(:configured?).with(:fake).and_return(true)

    expect(described_class.configured(credentials)).to eq([ Messengerr::Integrations::Fake ])
    expect(described_class.configured_by_method(:sms, credentials)).to eq([])
  end
end
