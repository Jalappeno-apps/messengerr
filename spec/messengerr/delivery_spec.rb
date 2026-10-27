RSpec.describe Messengerr::Delivery do
  let(:recipient) { Messengerr::Recipient.new(contact: "a@x.com", row: {}, row_number: 2) }

  it "defaults to a text body" do
    delivery = described_class.new(recipient:, body: "hi", subject: nil)

    expect(delivery.format).to eq(:text)
    expect(delivery).not_to be_html
  end

  it "can be an HTML body" do
    delivery = described_class.new(recipient:, body: "<p>hi</p>", subject: "s", format: :html)

    expect(delivery.format).to eq(:html)
    expect(delivery).to be_html
  end

  it "rejects an unknown format rather than guessing how to send it" do
    expect { described_class.new(recipient:, body: "x", subject: nil, format: :markdown) }
      .to raise_error(ArgumentError, /unknown delivery format/)
  end

  it "does not leak a FORMATS constant into the Messengerr namespace" do
    expect(Messengerr.const_defined?(:FORMATS, false)).to be(false)
  end
end
