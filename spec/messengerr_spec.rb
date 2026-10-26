RSpec.describe Messengerr do
  it "has a version" do
    expect(Messengerr::VERSION).to match(/\d+\.\d+\.\d+/)
  end

  it "eager loads without constant/filename mismatches" do
    expect { ::Messengerr.loader.eager_load }.not_to raise_error
  end
end
