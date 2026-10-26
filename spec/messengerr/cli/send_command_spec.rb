require "tmpdir"

RSpec.describe Messengerr::CLI::SendCommand do
  let(:fixture) { File.expand_path("../../fixtures/contacts.csv", __dir__) }

  around do |example|
    Dir.mktmpdir do |dir|
      @credentials = Messengerr::Credentials.new(
        credentials_path: File.join(dir, "credentials.yml.enc"),
        key_path: File.join(dir, "master.key")
      )
      example.run
    end
  end

  def run_wizard(script)
    input = StringIO.new(script)
    output = StringIO.new
    prompter = Messengerr::Prompter.new(input:, output:)
    command = described_class.new(prompter:, credentials: @credentials)
    [command.run, output.string]
  end

  it "aborts when no integrations are configured for the method" do
    code, output = run_wizard("2\n") # sms — fake is email-only
    expect(code).to eq(1)
    expect(output).to include("No sms integrations are configured")
    expect(output).to include("credentials setup")
  end

  it "runs the full flow: method → message → csv → mapping → validate → send → report" do
    @credentials.write(:fake, "token" => "ok")

    script = [
      "1",            # delivery method: email
      "Hi {{name}}",  # message
      "Welcome!",     # subject (email)
      fixture,        # csv path
      "1",            # map {{name}} → name column
      "2",            # contact column: email
      "y",            # drop defects
      "n"             # don't retry failures
    ].join("\n") + "\n"

    code, output = run_wizard(script)

    expect(output).to include("Columns: name, email, phone, fail")
    expect(output).to match(/row 4: "not-an-email" — invalid email address/)
    expect(output).to include("1 send(s) failed")
    expect(output).to match(/fails@example\.com.*fake send failure/)
    expect(output).to include("Done — sent: 3, failed: 1, dropped: 2")
    expect(code).to eq(1) # failures remain
  end

  it "aborts when the user declines to drop defects" do
    @credentials.write(:fake, "token" => "ok")

    script = ["1", "Hi {{name}}", "Sub", fixture, "1", "2", "n"].join("\n") + "\n"
    code, output = run_wizard(script)

    expect(code).to eq(1)
    expect(output).to include("Aborted")
  end

  it "aborts cleanly on a missing CSV" do
    @credentials.write(:fake, "token" => "ok")

    script = ["1", "Hi", "Sub", "/nope.csv"].join("\n") + "\n"
    code, output = run_wizard(script)

    expect(code).to eq(1)
    expect(output).to include("not found")
  end

  it "retries failed sends only when confirmed" do
    @credentials.write(:fake, "token" => "ok")

    # same happy path, but retry once — the fake fails the same row again
    script = ["1", "Hi {{name}}", "Sub", fixture, "1", "2", "y", "y", "n"].join("\n") + "\n"
    _, output = run_wizard(script)

    expect(output.scan("1 send(s) failed").length).to eq(2) # initial + retried
    expect(output).to include("Done — sent: 3, failed: 1, dropped: 2")
  end
end
