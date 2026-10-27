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

  it "leaves ordinary text untouched" do
    expect(described_class.render("plain {text} and 100%", row, mapping)).to eq("plain {text} and 100%")
  end

  it "never sends a malformed placeholder literally" do
    ["Hi {{first-name}}", "Hi {{first name}}", "plain {{}} text", "Hi {{name}} }}"].each do |template|
      expect { described_class.render(template, row, mapping) }
        .to raise_error(Messengerr::RenderError, /unrenderable placeholder/)
    end
  end

  it "does not re-expand placeholders found inside CSV values" do
    expect(described_class.render("Hi {{name}}", { "name" => "{x}" }, mapping)).to eq("Hi {x}")
  end
end
