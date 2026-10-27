RSpec.describe Messengerr::Placeholder do
  it "extracts unique placeholder names" do
    text = "Hi {{first_name}}, code {{code}}. Again {{ first_name }}!"
    expect(described_class.extract(text)).to eq(%w[first_name code])
  end

  it "tolerates whitespace inside braces" do
    expect(described_class.extract("{{ name }}")).to eq([ "name" ])
  end

  it "returns [] when no placeholders" do
    expect(described_class.extract("plain text {{}} {{ broken")).to eq([])
  end
end
