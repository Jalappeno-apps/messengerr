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
    [ "Hi {{first-name}}", "Hi {{first name}}", "plain {{}} text", "Hi {{name}} }}" ].each do |template|
      expect { described_class.render(template, row, mapping) }
        .to raise_error(Messengerr::RenderError, /unrenderable placeholder/)
    end
  end

  it "does not re-expand placeholders found inside CSV values" do
    expect(described_class.render("Hi {{name}}", { "name" => "{x}" }, mapping)).to eq("Hi {x}")
  end

  describe "HTML mode (escape: true)" do
    it "escapes every substituted value so CSV data cannot inject markup" do
      row = { "name" => %(<script>alert("x")</script> & 'Co') }
      html = described_class.render("<p>Hi {{name}}</p>", row, { "name" => "name" }, escape: true)

      expect(html).to eq("<p>Hi &lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt; &amp; &#39;Co&#39;</p>")
      expect(html).not_to include("<script>")
    end

    it "leaves the template's own markup alone" do
      expect(described_class.render("<b>{{name}}</b>", row, mapping, escape: true)).to eq("<b>Alice</b>")
    end

    it "does not escape in text mode (the default)" do
      expect(described_class.render("{{name}}", { "name" => "Tom & Jerry <3" }, mapping)).to eq("Tom & Jerry <3")
    end

    it "still refuses to send a leftover placeholder" do
      expect { described_class.render("<p>{{first-name}}</p>", row, mapping, escape: true) }
        .to raise_error(Messengerr::RenderError, /unrenderable placeholder/)
    end

    it "still reports an empty column" do
      expect { described_class.render("<p>{{name}}</p>", { "name" => " " }, mapping, escape: true) }
        .to raise_error(Messengerr::RenderError, /empty/)
    end
  end
end
