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

  describe "send flag errors (N4)" do
    def expect_clean_failure(argv, message)
      code, output = start(argv)
      expect(code).to eq(1)
      expect(output).to include("messengerr: ")
      expect(output).to include(message)
      expect(output).not_to include("Delivery method:") # failed before any prompt
    end

    it "reports an unknown flag instead of raising" do
      expect_clean_failure(%w[send --bogus], "invalid option: --bogus")
    end

    it "reports a non-numeric value" do
      expect_clean_failure(%w[send --batch-size abc], "invalid argument: --batch-size abc")
    end

    it "reports a missing value" do
      expect_clean_failure(%w[send --resume], "missing argument: --resume")
    end

    it "rejects non-positive numbers up front, not after the whole wizard" do
      expect_clean_failure(%w[send --batch-size 0], "must be a positive integer")
      expect_clean_failure(%w[send --rate-limit -3], "must be a positive integer")
    end

    it "rejects stray positional arguments" do
      expect_clean_failure(%w[send contacts.csv], "unexpected argument: contacts.csv")
    end

    it "points at the help" do
      _, output = start(%w[send --bogus])
      expect(output).to include("messengerr send --help")
    end

    it "prints send's flags with --help and exits 0 without prompting" do
      code, output = start(%w[send --help])
      expect(code).to eq(0)
      expect(output).to include("Usage: messengerr send [flags]")
      %w[--dry-run --resume --ledger --batch-size --rate-limit --from].each { |flag| expect(output).to include(flag) }
      expect(output).not_to include("Delivery method:")
    end

    it "mentions send --help in the top-level help" do
      _, output = start(%w[--help])
      expect(output).to include("send --help")
    end
  end
end
