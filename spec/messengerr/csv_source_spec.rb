RSpec.describe Messengerr::CsvSource do
  let(:fixture) { File.expand_path("../fixtures/contacts.csv", __dir__) }

  it "loads headers and rows" do
    source = described_class.from(fixture)
    expect(source.headers).to eq(%w[name email phone fail])
    expect(source.rows.length).to eq(6)
    expect(source.rows.first).to include("name" => "Alice", "email" => "alice@example.com")
  end

  it "raises a clear error for a missing file" do
    expect { described_class.from("/nope.csv") }
      .to raise_error(Messengerr::Error, /not found/)
  end

  it "raises on malformed CSV" do
    path = File.join(Dir.mktmpdir, "bad.csv")
    File.write(path, "a,b\n\"unclosed\n")
    expect { described_class.from(path) }.to raise_error(Messengerr::Error, /could not parse/)
  end
end
