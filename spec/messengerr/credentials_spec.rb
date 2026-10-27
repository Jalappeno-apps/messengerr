require "tmpdir"

RSpec.describe Messengerr::Credentials do
  around do |example|
    Dir.mktmpdir { |dir| @dir = dir; example.run }
  end

  let(:credentials_path) { File.join(@dir, "config", "credentials.yml.enc") }
  let(:key_path) { File.join(@dir, "config", "master.key") }
  let(:credentials) { described_class.new(credentials_path:, key_path:) }

  it "writes and reads back integration credentials" do
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

  it "merges multiple integrations" do
    credentials.write(:postmark, { server_token: "abc" })
    credentials.write(:clicksend, { username: "u" })
    expect(credentials.keys).to contain_exactly("postmark", "clicksend")
  end

  it "reports configured? only for stored integrations" do
    credentials.write(:postmark, { server_token: "abc" })
    expect(credentials.configured?(:postmark)).to be(true)
    expect(credentials.configured?(:clicksend)).to be(false)
  end

  it "returns nil for unconfigured integrations" do
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

  describe "MESSENGERR_MASTER_KEY (N8)" do
    let(:good_key) { "ab" * 32 }

    it "uses a valid env key and never writes a key file" do
      with_env("MESSENGERR_MASTER_KEY" => good_key) do
        credentials.write(:postmark, { server_token: "abc" })
        expect(described_class.new(credentials_path:, key_path:).read(:postmark)).to eq("server_token" => "abc")
        expect(File.exist?(key_path)).to be(false)
      end
    end

    it "accepts surrounding whitespace and uppercase hex" do
      with_env("MESSENGERR_MASTER_KEY" => "  #{good_key.upcase}\n") do
        credentials.write(:postmark, { server_token: "abc" })
        expect(credentials.read(:postmark)).to eq("server_token" => "abc")
      end
    end

    it "rejects malformed keys with a clear CredentialsError (not a raw ArgumentError)" do
      [ "abc", "zz" * 32, "ab" * 31, "ab" * 33 ].each do |bad|
        with_env("MESSENGERR_MASTER_KEY" => bad) do
          expect { credentials.write(:postmark, { server_token: "abc" }) }
            .to raise_error(Messengerr::CredentialsError, /64 hex characters/), "expected #{bad.length}-char key to be rejected"
        end
      end
    end

    it "rejects an empty key rather than silently falling back to a key file" do
      [ "", "  " ].each do |blank|
        with_env("MESSENGERR_MASTER_KEY" => blank) do
          expect { credentials.write(:postmark, { server_token: "abc" }) }
            .to raise_error(Messengerr::CredentialsError, /set but empty/)
          expect(File.exist?(key_path)).to be(false)
        end
      end
    end

    it "does not echo the rejected value" do
      with_env("MESSENGERR_MASTER_KEY" => "not-hex-secret-value") do
        expect { credentials.read(:postmark) }.not_to raise_error # nothing stored yet, so no key needed
        expect { credentials.write(:postmark, { a: "b" }) }
          .to raise_error(Messengerr::CredentialsError) { |e| expect(e.message).not_to include("not-hex-secret-value") }
      end
    end

    it "reports a wrong (but valid) env key as undecryptable" do
      with_env("MESSENGERR_MASTER_KEY" => good_key) { credentials.write(:postmark, { server_token: "abc" }) }
      with_env("MESSENGERR_MASTER_KEY" => "cd" * 32) do
        expect { credentials.read(:postmark) }.to raise_error(Messengerr::CredentialsError, /could not be decrypted/)
      end
    end
  end

  describe "directory permissions (N10)" do
    around { |example| with_env("MESSENGERR_MASTER_KEY" => nil) { example.run } }

    it "creates a missing config directory owner-only" do
      credentials.write(:postmark, { server_token: "abc" })
      expect(File.stat(File.dirname(credentials_path)).mode & 0o777).to eq(0o700)
    end

    it "never changes the permissions of a directory that already exists" do
      shared = File.join(@dir, "shared")
      Dir.mkdir(shared)
      File.chmod(0o755, shared)
      shared_creds = described_class.new(
        credentials_path: File.join(shared, "credentials.yml.enc"), key_path: File.join(shared, "master.key")
      )

      shared_creds.write(:postmark, { server_token: "abc" })

      expect(File.stat(shared).mode & 0o777).to eq(0o755)
      expect(File.stat(File.join(shared, "credentials.yml.enc")).mode & 0o777).to eq(0o600)
      expect(File.stat(File.join(shared, "master.key")).mode & 0o777).to eq(0o600)
    end
  end
end
