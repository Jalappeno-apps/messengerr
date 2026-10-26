RSpec.describe Messengerr::SendingOptions::Postmark do
  it "extends base options with postmark-specific ones" do
    options = described_class.new(subject: "Hi", tag: "promo", message_stream: "outbound", track_opens: true)
    expect(options.to_h).to include(subject: "Hi", tag: "promo", message_stream: "outbound", track_opens: true)
  end

  it "requires a subject" do
    expect { described_class.new.validate! }.to raise_error(Messengerr::ValidationError, /subject/)
  end
end
