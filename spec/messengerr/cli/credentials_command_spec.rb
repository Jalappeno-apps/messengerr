require "tmpdir"

RSpec.describe Messengerr::CLI::CredentialsCommand do
  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      @credentials = Messengerr::Credentials.new(
        credentials_path: File.join(dir, "credentials.yml.enc"),
        key_path: File.join(dir, "master.key")
      )
      example.run
    end
  end

  def run_command(args, script = "")
    input = StringIO.new(script)
    output = StringIO.new
    prompter = Messengerr::Prompter.new(input:, output:)
    command = described_class.new(prompter:, credentials: @credentials)
    [ command.run(args), output.string ]
  end

  it "setup runs the integration's wizard" do
    code, output = run_command(%w[setup fake], "tok\n\n")
    expect(code).to eq(0)
    expect(@credentials.read(:fake)).to eq("token" => "tok")
    expect(output).to include("configured and verified")
  end

  it "setup rejects unknown integrations" do
    code, output = run_command(%w[setup nope])
    expect(code).to eq(1)
    expect(output).to include("Unknown integration")
  end

  it "list shows configured state" do
    @credentials.write(:fake, "token" => "tok")
    _, output = run_command(%w[list])
    expect(output).to match(/fake \(email\) — configured/)
    expect(output).to match(/postmark \(email\) — not configured/)
    expect(output).to match(/clicksend \(sms\) — not configured/)
  end

  it "verify reports unconfigured integrations" do
    code, output = run_command(%w[verify fake])
    expect(code).to eq(1)
    expect(output).to include("not configured")
  end

  it "verify succeeds against stored credentials" do
    @credentials.write(:fake, "token" => "tok")
    code, output = run_command(%w[verify fake])
    expect(code).to eq(0)
    expect(output).to include("verified")
  end

  it "verify reports failures" do
    @credentials.write(:fake, "token" => "bad")
    code, output = run_command(%w[verify fake])
    expect(code).to eq(1)
    expect(output).to include("bad token")
  end

  it "delete requires confirmation and removes the file" do
    @credentials.write(:fake, "token" => "tok")
    code, output = run_command(%w[delete], "y\n")
    expect(code).to eq(0)
    expect(@credentials.exists?).to be(false)
    expect(output).to include("Deleted")
  end

  it "delete --purge removes the master key too" do
    @credentials.write(:fake, "token" => "tok")
    run_command(%w[delete --purge], "y\n")
    expect(File.exist?(File.join(@dir, "master.key"))).to be(false)
  end

  it "aborts delete when not confirmed" do
    @credentials.write(:fake, "token" => "tok")
    run_command(%w[delete], "n\n")
    expect(@credentials.exists?).to be(true)
  end
end
