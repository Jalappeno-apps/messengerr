RSpec.describe Messengerr::SendingOptions::Postmark do
  it "extends base options with postmark-specific ones" do
    options = described_class.new(subject: "Hi", tag: "promo", message_stream: "outbound", track_opens: true)
    expect(options.to_h).to include(subject: "Hi", tag: "promo", message_stream: "outbound", track_opens: true)
  end

  it "does not require a subject (it is supplied per delivery)" do
    expect(described_class.new.validate!).to be(true)
  end
end
