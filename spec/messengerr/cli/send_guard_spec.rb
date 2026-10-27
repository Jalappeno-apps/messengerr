require "tmpdir"

RSpec.describe "send interactive guard and flags" do
  let(:fixture) { File.expand_path("../../fixtures/contacts.csv", __dir__) }

  around do |example|
    Dir.mktmpdir do |dir|
      @ledger = File.join(dir, "ledger.jsonl")
      @credentials = Messengerr::Credentials.new(
        credentials_path: File.join(dir, "credentials.yml.enc"),
        key_path: File.join(dir, "master.key")
      )
      example.run
    end
  end

  # Mirrors CLI.start: Messengerr::Error prints a message and exits 1.
  def run_wizard(script, args, interactive: false)
    input = StringIO.new(script)
    output = StringIO.new
    prompter = Messengerr::Prompter.new(input:, output:, interactive:)
    command = Messengerr::CLI::SendCommand.new(prompter:, credentials: @credentials)
    code =
      begin
        command.run([ "--ledger", @ledger, *args ])
      rescue Messengerr::Error => e
        output.puts "messengerr: #{e.message}"
        1
      end
    [ code, output.string ]
  end

  it "refuses a real send without an interactive terminal" do
    @credentials.write(:fake, "token" => "ok")
    code, output = run_wizard("", [ "--method", "email", "--csv", fixture, "--contact", "email",
                                    "--map", "name=name", "--message", "Hi {{name}}", "--subject", "S" ])
    expect(code).to eq(1)
    expect(output).to include("refusing to send without an interactive terminal")
    expect(output).to include("--allow-non-interactive")
  end

  it "lets a dry run run non-interactively" do
    @credentials.write(:fake, "token" => "ok")
    code, output = run_wizard("y\n", [ "--method", "email", "--csv", fixture, "--contact", "email",
                                      "--map", "name=name", "--message", "Hi {{name}}", "--subject", "S",
                                      "--dry-run" ])
    expect(code).to eq(0)
    expect(output).to include("Dry run — nothing sent")
    expect(output).to include("To: alice@example.com")
  end

  it "sends non-interactively only with --allow-non-interactive" do
    @credentials.write(:fake, "token" => "ok")
    code, output = run_wizard("y\ny\nn\n", [ "--method", "email", "--csv", fixture, "--contact", "email",
                                         "--map", "name=name", "--message", "Hi {{name}}", "--subject", "S",
                                         "--allow-non-interactive" ])
    expect(code).to eq(1) # failures remain (fake send failure row)
    expect(output).to include("Done — sent: 3, failed: 1, dropped: 2")
    expect(File.read(@ledger)).to include("alice@example.com")
  end

  it "drives the whole flow with flags and no wizard answers" do
    @credentials.write(:fake, "token" => "ok")
    # Only the defect-drop confirm needs an answer; everything else is flags.
    code, output = run_wizard("y\n", [ "--method", "email", "--csv", fixture, "--contact", "email",
                                      "--map", "name=name", "--message", "Hi {{name}}",
                                      "--subject", "Welcome {{name}}", "--dry-run" ])
    expect(code).to eq(0)
    expect(output).to include("Subject: Welcome Alice")
    expect(output).not_to include("Delivery method:")
    expect(output).not_to include("Path to CSV")
    expect(output).not_to include("Map {{name}}")
  end

  it "rejects --integration that is not configured" do
    @credentials.write(:fake, "token" => "ok")
    code, output = run_wizard("", [ "--method", "email", "--integration", "postmark",
                                    "--csv", fixture, "--contact", "email", "--map", "name=name",
                                    "--message", "Hi", "--subject", "S", "--dry-run" ])
    expect(code).to eq(1)
    expect(output).to include("not configured")
  end

  it "rejects --map to a nonexistent column" do
    @credentials.write(:fake, "token" => "ok")
    code, output = run_wizard("y\n", [ "--method", "email", "--csv", fixture, "--contact", "email",
                                      "--map", "name=nope", "--message", "Hi {{name}}", "--subject", "S",
                                      "--dry-run" ])
    expect(code).to eq(1)
    expect(output).to include("no such column")
  end

  it "rejects --contact to a nonexistent column" do
    @credentials.write(:fake, "token" => "ok")
    code, output = run_wizard("y\n", [ "--method", "email", "--csv", fixture, "--contact", "nope",
                                      "--map", "name=name", "--message", "Hi", "--subject", "S",
                                      "--dry-run" ])
    expect(code).to eq(1)
    expect(output).to include("no such column")
  end

  it "rejects conflicting message flags" do
    code, output = run_wizard("", [ "--message", "hi", "--message-file", fixture, "--dry-run" ])
    expect(code).to eq(1)
    expect(output).to include("not both")
  end

  it "rejects malformed --map" do
    code, output = run_wizard("", [ "--map", "noequals", "--dry-run" ])
    expect(code).to eq(1)
    expect(output).to include("PLACEHOLDER=COLUMN")
  end

  describe "blank flag values" do
    %w[--message --subject --csv --contact --integration].each do |flag|
      it "rejects a blank #{flag} before any prompt" do
        code, output = run_wizard("", [ flag, "   " ])

        expect(code).to eq(1)
        expect(output).to include("#{flag} can't be blank")
        expect(output).not_to include("Delivery method")
      end
    end

    it "never previews or sends an empty message" do
      @credentials.write(:fake, "token" => "ok")
      code, output = run_wizard("", [ "--method", "email", "--csv", fixture, "--contact", "email",
                                      "--message", "", "--subject", "S", "--dry-run" ])

      expect(code).to eq(1)
      expect(output).not_to include("--- Preview")
    end
  end

  it "rejects --subject for SMS" do
    code, output = run_wizard("", [ "--method", "sms", "--subject", "Hello", "--dry-run" ])

    expect(code).to eq(1)
    expect(output).to include("--subject is only for email")
  end

  describe "an unused --map" do
    it "warns by name (likely a typo) but carries on" do
      @credentials.write(:fake, "token" => "ok")
      code, output = run_wizard("y\n", [ "--method", "email", "--csv", fixture, "--contact", "email",
                                         "--map", "name=name", "--map", "nmae=name", "--message", "Hi {{name}}",
                                         "--subject", "S", "--dry-run" ])

      expect(code).to eq(0)
      expect(output).to include("Note: --map nmae not used")
      expect(output).to include("Dry run — nothing sent")
    end

    it "does not warn when every mapping is used (message or subject)" do
      @credentials.write(:fake, "token" => "ok")
      _, output = run_wizard("y\n", [ "--method", "email", "--csv", fixture, "--contact", "email",
                                      "--map", "name=name", "--map", "email=email", "--message", "Hi {{name}}",
                                      "--subject", "To {{email}}", "--dry-run" ])

      expect(output).not_to include("Note: --map")
    end
  end

  it "tells the user what to do when a real send is refused" do
    @credentials.write(:fake, "token" => "ok")
    _, output = run_wizard("", [ "--method", "email", "--csv", fixture, "--contact", "email",
                                 "--map", "name=name", "--message", "Hi {{name}}", "--subject", "S" ])

    expect(output).to include("run `messengerr send` yourself in a terminal")
    expect(output).to include("--dry-run works anywhere")
  end

  it "refuses before reading the CSV or touching the ledger" do
    @credentials.write(:fake, "token" => "ok")
    run_wizard("", [ "--method", "email", "--csv", fixture, "--contact", "email", "--message", "Hi" ])

    expect(File.exist?(@ledger)).to be(false)
  end
end
