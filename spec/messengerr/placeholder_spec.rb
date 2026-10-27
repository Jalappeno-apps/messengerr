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

  it "finds no placeholder names in logic-style templates" do
    [ "{{#if name}}x{{/if}}", "{{ name | upcase }}", '{{name ? "a" : "b"}}', "{{ name + plan }}", "{{> partial}}", "{{ name.upcase }}" ].each do |template|
      expect(described_class.extract(template)).to eq([]), "expected no placeholders in #{template}"
    end
  end

  it "ignores spaces inside the braces but nothing else" do
    expect(described_class.extract("{{ name }} {{plan}} {{  code  }}")).to eq(%w[name plan code])
  end
end
