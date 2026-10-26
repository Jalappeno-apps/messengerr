RSpec.describe Messengerr::Renderer do
  let(:row) { { "name" => "Alice", "plan" => "Pro" } }
  let(:mapping) { { "name" => "name", "plan" => "plan" } }

  it "substitutes mapped placeholders" do
    expect(described_class.render("Hi {{name}} on {{plan}}!", row, mapping))
      .to eq("Hi Alice on Pro!")
  end

  it "raises RenderError for an unmapped placeholder" do
    expect { described_class.render("Hi {{unknown}}", row, mapping) }
      .to raise_error(Messengerr::RenderError, /no column mapped/)
  end

  it "raises RenderError for an empty column value" do
    expect { described_class.render("Hi {{name}}", { "name" => " " }, mapping) }
      .to raise_error(Messengerr::RenderError, /empty/)
  end

  it "leaves non-placeholder text untouched" do
    expect(described_class.render("plain {{}} text", row, mapping)).to eq("plain {{}} text")
  end
end
