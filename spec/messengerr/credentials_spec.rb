require "tmpdir"

RSpec.describe Messengerr::Credentials do
  around do |example|
    Dir.mktmpdir { |dir| @dir = dir; example.run }
  end

  let(:credentials_path) { File.join(@dir, "config", "credentials.yml.enc") }
  let(:key_path) { File.join(@dir, "config", "master.key") }
  let(:credentials) { described_class.new(credentials_path:, key_path:) }

  it "writes and reads back service credentials" do
    credentials.write(:postmark, { server_token: "abc", from: "me@x.com" })
    expect(credentials.read(:postmark)).to eq("server_token" => "abc", "from" => "me@x.com")
  end

  it "persists across instances" do
    credentials.write(:clicksend, { username: "u", api_key: "k" })
    fresh = described_class.new(credentials_path:, key_path:)
    expect(fresh.read(:clicksend)).to eq("username" => "u", "api_key" => "k")
  end

  it "encrypts the file contents" do
    credentials.write(:postmark, { server_token: "abc" })
    expect(File.read(credentials_path)).not_to include("abc")
  end

  it "generates a master key once" do
    credentials.write(:postmark, { server_token: "abc" })
    first_key = File.read(key_path)
    credentials.write(:clicksend, { username: "u" })
    expect(File.read(key_path)).to eq(first_key)
  end

  it "restricts file permissions" do
    credentials.write(:postmark, { server_token: "abc" })
    expect(File.stat(key_path).mode & 0o777).to eq(0o600)
    expect(File.stat(credentials_path).mode & 0o777).to eq(0o600)
  end

  it "merges multiple services" do
    credentials.write(:postmark, { server_token: "abc" })
    credentials.write(:clicksend, { username: "u" })
    expect(credentials.keys).to contain_exactly("postmark", "clicksend")
  end

  it "reports configured? only for stored services" do
    credentials.write(:postmark, { server_token: "abc" })
    expect(credentials.configured?(:postmark)).to be(true)
    expect(credentials.configured?(:clicksend)).to be(false)
  end

  it "returns nil for unconfigured services" do
    expect(credentials.read(:nope)).to be_nil
  end

  it "delete_file! removes the encrypted file but keeps the key" do
    credentials.write(:postmark, { server_token: "abc" })
    credentials.delete_file!
    expect(File.exist?(credentials_path)).to be(false)
    expect(File.exist?(key_path)).to be(true)
    expect(credentials.keys).to eq([])
  end

  it "purge! removes both files" do
    credentials.write(:postmark, { server_token: "abc" })
    credentials.purge!
    expect(File.exist?(credentials_path)).to be(false)
    expect(File.exist?(key_path)).to be(false)
  end

  it "raises a clear error when the key is lost" do
    credentials.write(:postmark, { server_token: "abc" })
    FileUtils.rm_f(key_path)
    expect { credentials.read(:postmark) }
      .to raise_error(Messengerr::CredentialsError, /credentials delete/)
  end

  it "raises CredentialsError on a corrupted file" do
    credentials.write(:postmark, { server_token: "abc" })
    File.write(credentials_path, "garbage")
    expect { credentials.read(:postmark) }
      .to raise_error(Messengerr::CredentialsError)
  end
end
