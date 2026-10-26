RSpec.describe Messengerr::SendingOptions::Base do
  it "has sensible defaults" do
    options = described_class.new
    expect(options.batch_size).to eq(50)
    expect(options.rate_limit).to eq(10)
    expect(options.metadata).to eq({})
  end

  it "assigns known options" do
    options = described_class.new(from: "me@x.com", batch_size: 10)
    expect(options.from).to eq("me@x.com")
    expect(options.batch_size).to eq(10)
  end

  it "validate! accepts defaults" do
    expect(described_class.new.validate!).to be(true)
  end

  it "validate! rejects bad values" do
    expect { described_class.new(batch_size: 0).validate! }
      .to raise_error(Messengerr::ValidationError, /batch_size/)
    expect { described_class.new(rate_limit: -1).validate! }
      .to raise_error(Messengerr::ValidationError, /rate_limit/)
  end

  it "subclasses inherit and extend options" do
    subclass = Class.new(described_class) { option :tag }
    options = subclass.new(tag: "promo", batch_size: 5)
    expect(options.to_h).to include(tag: "promo", batch_size: 5, from: nil)
    expect(described_class.options).not_to include(:tag)
  end
end
