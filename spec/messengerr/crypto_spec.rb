RSpec.describe Messengerr::Crypto do
  let(:key) { SecureRandom.random_bytes(32) }

  it "round-trips plaintext" do
    payload = described_class.encrypt("hello world", key)
    expect(described_class.decrypt(payload, key)).to eq("hello world")
  end

  it "produces different ciphertext for the same plaintext" do
    expect(described_class.encrypt("x", key)).not_to eq(described_class.encrypt("x", key))
  end

  it "raises CredentialsError on wrong key" do
    payload = described_class.encrypt("secret", key)
    expect { described_class.decrypt(payload, SecureRandom.random_bytes(32)) }
      .to raise_error(Messengerr::CredentialsError)
  end

  it "raises CredentialsError on malformed payload" do
    expect { described_class.decrypt("!!!", key) }
      .to raise_error(Messengerr::CredentialsError)
  end
end
