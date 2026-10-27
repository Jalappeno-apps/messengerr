require_relative "../../rakelib/docs_integrations"

RSpec.describe DocsIntegrations do
  let(:page) { described_class.render }

  # The test-only Fake integration is registered by spec/support; the docs describe the shipped ones.
  before do
    shipped = Messengerr::Registry.all.reject { |integration| integration.integration_key == :fake }
    allow(Messengerr::Registry).to receive(:all).and_return(shipped)
  end

  it "lists every built-in integration with its delivery method and credential keys" do
    expect(page).to include("| [`postmark`](#postmark) | email | `server_token`, `from` | none |")
    expect(page).to include("| [`clicksend`](#clicksend) | sms | `username`, `api_key` | `from` |")
  end

  it "marks which sending options the command line can set" do
    expect(page).to include("| `batch_size` | `--batch-size` |")
    expect(page).to include("| `message_stream` | not exposed yet |")
  end

  it "states ClickSend's batch limit from the code" do
    expect(page).to include("**Maximum batch size:** #{Messengerr::SendingOptions::ClickSend::MAX_BATCH}")
  end

  it "has the front matter the docs site needs" do
    expect(page).to start_with("---\ntitle: Integrations\nnav_order: 8\n")
  end

  it "fails loudly when a sending option has no description, so the docs cannot silently go stale" do
    stub_const("DocsIntegrations::DESCRIPTIONS", {})

    expect { described_class.render }.to raise_error(/add a DESCRIPTIONS entry for sending option/)
  end

  it "matches the committed docs/integrations.md (run `rake docs:integrations` if this fails)" do
    expect(File.read(described_class::PATH, encoding: "UTF-8")).to eq(described_class.render)
  end
end
