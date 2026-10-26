require "tmpdir"

RSpec.describe Messengerr::Setups::Base do
  around do |example|
    Dir.mktmpdir do |dir|
      @credentials = Messengerr::Credentials.new(
        credentials_path: File.join(dir, "credentials.yml.enc"),
        key_path: File.join(dir, "master.key")
      )
      example.run
    end
  end

  def build_setup(script)
    input = StringIO.new(script)
    output = StringIO.new
    prompter = Messengerr::Prompter.new(input:, output:)
    setup = Messengerr::Setups::Fake.new(prompter:, credentials: @credentials)
    [setup, output]
  end

  it "prompts required keys, verifies, and stores credentials" do
    setup, output = build_setup("tok123\n\n")
    expect(setup.run).to be(true)
    expect(@credentials.read(:fake)).to eq("token" => "tok123")
    expect(output.string).to include("configured and verified")
  end

  it "stores optional keys when provided" do
    setup, = build_setup("tok123\neu-west\n")
    setup.run
    expect(@credentials.read(:fake)).to eq("token" => "tok123", "region" => "eu-west")
  end

  it "aborts when a required key is blank" do
    setup, output = build_setup("\n")
    expect(setup.run).to be(false)
    expect(output.string).to include("required")
    expect(@credentials.read(:fake)).to be_nil
  end

  it "offers retry when verification fails" do
    setup, output = build_setup("bad\n\ny\ntok123\n\n")
    expect(setup.run).to be(true)
    expect(output.string).to include("Verification failed")
    expect(@credentials.read(:fake)["token"]).to eq("tok123")
  end

  it "returns false when the user declines a retry" do
    setup, = build_setup("bad\n\nn\n")
    expect(setup.run).to be(false)
    expect(@credentials.read(:fake)).to be_nil
  end
end
