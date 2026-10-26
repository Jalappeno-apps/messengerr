require "tmpdir"

RSpec.describe Messengerr::CLI do
  def start(argv, script: "")
    out = StringIO.new
    input = StringIO.new(script)
    Dir.mktmpdir do |dir|
      credentials = Messengerr::Credentials.new(
        credentials_path: File.join(dir, "credentials.yml.enc"),
        key_path: File.join(dir, "master.key")
      )
      code = described_class.start(argv, prompter: Messengerr::Prompter.new(input:, output: out), credentials:, out:)
      return code, out.string
    end
  end

  it "prints help on --help and no args" do
    %w[--help -h].each do |flag|
      code, output = start([flag])
      expect(code).to eq(0)
      expect(output).to include("credentials")
    end
    expect(start([]).first).to eq(0)
  end

  it "prints the version" do
    code, output = start(["--version"])
    expect(code).to eq(0)
    expect(output.strip).to eq(Messengerr::VERSION)
  end

  it "rejects unknown commands" do
    code, output = start(["bogus"])
    expect(code).to eq(1)
    expect(output).to include("unknown command")
  end

  it "dispatches to credentials" do
    code, output = start(%w[credentials list])
    expect(code).to eq(0)
    expect(output).to include("Registered integrations")
  end

  it "dispatches to integrations" do
    code, output = start(%w[integrations])
    expect(code).to eq(0)
    expect(output).to include("email:")
    expect(output).to include("sms:")
  end
end
