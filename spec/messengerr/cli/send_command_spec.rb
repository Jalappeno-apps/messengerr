require "tmpdir"
require "json"

RSpec.describe Messengerr::CLI::SendCommand do
  let(:fixture) { File.expand_path("../../fixtures/contacts.csv", __dir__) }

  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      @ledger = File.join(dir, "ledger.jsonl")
      @credentials = Messengerr::Credentials.new(
        credentials_path: File.join(dir, "credentials.yml.enc"),
        key_path: File.join(dir, "master.key")
      )
      example.run
    end
  end

  def run_wizard(script, args = [])
    input = StringIO.new(script)
    output = StringIO.new
    prompter = Messengerr::Prompter.new(input:, output:)
    command = described_class.new(prompter:, credentials: @credentials)
    [ command.run([ "--ledger", @ledger, *args ]), output.string ]
  end

  it "aborts when no integrations are configured for the method" do
    code, output = run_wizard("2\n") # sms — fake is email-only
    expect(code).to eq(1)
    expect(output).to include("No sms integrations are configured")
    expect(output).to include("credentials setup")
  end

  it "runs the full flow: method → message → csv → mapping → validate → preview → confirm → send → report" do
    @credentials.write(:fake, "token" => "ok")

    script = [
      "1",            # delivery method: email
      "Hi {{name}}",  # message
      "Welcome!",     # subject (email)
      fixture,        # csv path
      "1",            # map {{name}} → name column
      "2",            # contact column: email
      "y",            # drop defects
      "y",            # confirm send
      "n"             # don't retry failures
    ].join("\n") + "\n"

    code, output = run_wizard(script)

    expect(output).to include("Columns: name, email, phone, fail")
    expect(output).to match(/row 4: "not-an-email" — invalid email address/)
    expect(output).to include("--- Preview (4 messages) ---")
    expect(output).to include("1 send(s) failed")
    expect(output).to match(/fails@example\.com.*fake send failure/)
    expect(output).to include("Done — sent: 3, failed: 1, dropped: 2")
    expect(code).to eq(1) # failures remain
    expect(File.readlines(@ledger).length).to eq(4)
  end

  it "aborts when the user declines to drop defects" do
    @credentials.write(:fake, "token" => "ok")

    script = [ "1", "Hi {{name}}", "Sub", fixture, "1", "2", "n" ].join("\n") + "\n"
    code, output = run_wizard(script)

    expect(code).to eq(1)
    expect(output).to include("Aborted")
  end

  it "sends nothing when the user declines the final confirmation" do
    @credentials.write(:fake, "token" => "ok")

    script = [ "1", "Hi {{name}}", "Sub", fixture, "1", "2", "y", "n" ].join("\n") + "\n"
    code, output = run_wizard(script)

    expect(code).to eq(1)
    expect(output).to include("Aborted — nothing was sent.")
    expect(File.exist?(@ledger)).to be(false)
  end

  it "previews but sends nothing with --dry-run" do
    @credentials.write(:fake, "token" => "ok")

    script = [ "1", "Hi {{name}}", "Sub", fixture, "1", "2", "y" ].join("\n") + "\n"
    code, output = run_wizard(script, [ "--dry-run" ])

    expect(code).to eq(0)
    expect(output).to include("--- Preview")
    expect(output).to include("Dry run — nothing sent")
    expect(output).not_to include("Done —")
    expect(File.exist?(@ledger)).to be(false)
  end

  it "aborts cleanly on a missing CSV" do
    @credentials.write(:fake, "token" => "ok")

    script = [ "1", "Hi", "Sub", "/nope.csv" ].join("\n") + "\n"
    code, output = run_wizard(script)

    expect(code).to eq(1)
    expect(output).to include("not found")
  end

  it "re-asks until an email subject is given" do
    @credentials.write(:fake, "token" => "ok")

    script = [ "1", "Hi", "  ", "Real subject", "/nope.csv" ].join("\n") + "\n"
    _, output = run_wizard(script)

    expect(output).to include("A subject is required for email.")
    expect(output).to include("not found") # got past the subject prompt
  end

  it "retries failed sends only when confirmed" do
    @credentials.write(:fake, "token" => "ok")

    # same happy path, but retry once — the fake fails the same row again
    script = [ "1", "Hi {{name}}", "Sub", fixture, "1", "2", "y", "y", "y", "n" ].join("\n") + "\n"
    _, output = run_wizard(script)

    expect(output.scan("1 send(s) failed").length).to eq(2) # initial + retried
    expect(output).to include("Done — sent: 3, failed: 1, dropped: 2")
  end

  it "skips contacts already sent in the ledger with --resume" do
    @credentials.write(:fake, "token" => "ok")
    File.write(@ledger, [
      { row_number: 2, contact: "alice@example.com", status: "sent" },
      { row_number: 7, contact: "fails@example.com", status: "failed" }
    ].map(&:to_json).join("\n") + "\n")
    before = File.readlines(@ledger).length

    script = [ "1", "Hi {{name}}", "Sub", fixture, "1", "2", "y", "y", "n" ].join("\n") + "\n"
    _, output = run_wizard(script, [ "--resume", @ledger ])

    expect(output).to include("Resuming: 1 already sent, 3 remaining.")
    sent_now = File.readlines(@ledger).drop(before).map { |l| JSON.parse(l)["contact"] }
    expect(sent_now).not_to include("alice@example.com")
    expect(sent_now).to include("bob@example.com")
  end

  describe "--resume safety (N2)" do
    before { @credentials.write(:fake, "token" => "ok") }

    it "refuses a ledger path that doesn't exist instead of treating it as 'nothing sent'" do
      expect { run_wizard("", [ "--resume", File.join(@dir, "typo.jsonl") ]) }
        .to raise_error(Messengerr::Error, /resume ledger not found/)
    end

    it "warns about contacts whose earlier attempt had an unknown outcome" do
      File.write(@ledger, [
        { row_number: 2, contact: "alice@example.com", status: "sent" },
        { row_number: 7, contact: "fails@example.com", status: "failed", uncertain: true }
      ].map(&:to_json).join("\n") + "\n")

      script = [ "1", "Hi {{name}}", "Sub", fixture, "1", "2", "y", "n" ].join("\n") + "\n"
      _, output = run_wizard(script, [ "--resume", @ledger ])

      expect(output).to include("1 contact(s) had an earlier attempt with an unknown outcome")
      expect(output).to include("fails@example.com")
      expect(output).to include("may receive duplicates")
    end

    it "resumes per row when a contact appears more than once" do
      csv = File.join(@dir, "repeats.csv")
      File.write(csv, "name,email\nAnn,dup@x.com\nAnn again,dup@x.com\nBob,bob@x.com\n")
      File.write(@ledger, { row_number: 2, contact: "dup@x.com", status: "sent" }.to_json + "\n")

      script = [ "1", "Hi {{name}}", "Sub", csv, "1", "2", "y", "n" ].join("\n") + "\n"
      _, output = run_wizard(script, [ "--resume", @ledger ])

      expect(output).to include("Resuming: 1 already sent, 2 remaining.")
      expect(output).to include("Hi Ann again") # row 3, same address, still sent
      sent_rows = File.readlines(@ledger).drop(1).map { |l| JSON.parse(l)["row_number"] }
      expect(sent_rows).to contain_exactly(3, 4)
    end

    it "does not warn when no earlier attempt was uncertain" do
      File.write(@ledger, { row_number: 2, contact: "alice@example.com", status: "sent" }.to_json + "\n")

      script = [ "1", "Hi {{name}}", "Sub", fixture, "1", "2", "y", "n" ].join("\n") + "\n"
      _, output = run_wizard(script, [ "--resume", @ledger ])

      expect(output).not_to include("unknown outcome")
    end
  end

  describe "ledger and interruption handling (N1/N2)" do
    before { @credentials.write(:fake, "token" => "ok") }

    let(:script) { [ "1", "Hi {{name}}", "Sub", fixture, "1", "2", "y", "y" ].join("\n") + "\n" }

    it "aborts before sending anything if the ledger can't be written" do
      skip "root can write anywhere" if Process.uid.zero?
      ro = File.join(@dir, "ro")
      FileUtils.mkdir_p(ro)
      File.chmod(0o500, ro)
      expect_any_instance_of(Messengerr::Integrations::Fake).not_to receive(:send_batch)

      expect { run_wizard(script, [ "--ledger", File.join(ro, "l.jsonl") ]) }
        .to raise_error(Messengerr::Error, /cannot write ledger/)
    ensure
      File.chmod(0o700, File.join(@dir, "ro"))
    end

    it "on Ctrl-C exits 130, prints how to resume, and leaves an honest ledger" do
      allow_any_instance_of(Messengerr::Integrations::Fake).to receive(:send_batch).and_raise(Interrupt)

      code, output = run_wizard(script)

      expect(code).to eq(130)
      expect(output).to include("Interrupted.")
      expect(output).to include("messengerr send --resume #{@ledger}")
      entries = File.readlines(@ledger).map { |l| JSON.parse(l) }
      expect(entries.length).to eq(4)
      expect(entries).to all(include("status" => "failed", "uncertain" => true, "reason" => "interrupted"))
    end
  end

  describe "with the real Postmark integration (email end-to-end)" do
    let(:csv) { File.join(@dir, "people.csv") }

    before do
      File.write(csv, "name,email\nAnn,ann@x.com\nBob,bob@x.com\n")
      @credentials.write(:postmark, "server_token" => "tok", "from" => "me@x.com")
    end

    def stub_postmark
      stub_request(:post, "https://api.postmarkapp.com/email")
        .to_return(status: 200, body: '{"MessageID":"pm-1","ErrorCode":0}')
    end

    it "sends each rendered subject and body after confirmation (regression: R1)" do
      stub = stub_postmark
      script = [ "1", "Hi {{name}}", "Hello {{name}}", csv, "1", "2", "y", "n" ].join("\n") + "\n"
      code, output = run_wizard(script)

      expect(output).not_to include("subject is required")
      expect(output).to include("Done — sent: 2, failed: 0, dropped: 0")
      expect(code).to eq(0)
      expect(stub.with { |r| b = JSON.parse(r.body); [ b["To"], b["Subject"], b["TextBody"], b["From"] ] == [ "ann@x.com", "Hello Ann", "Hi Ann", "me@x.com" ] })
        .to have_been_requested
      expect(stub.with { |r| JSON.parse(r.body).values_at("To", "Subject") == [ "bob@x.com", "Hello Bob" ] })
        .to have_been_requested
      expect(File.readlines(@ledger).length).to eq(2)
    end

    it "makes no API call on --dry-run" do
      stub = stub_postmark
      script = [ "1", "Hi {{name}}", "Hello", csv, "1", "2" ].join("\n") + "\n"
      code, output = run_wizard(script, [ "--dry-run" ])

      expect(code).to eq(0)
      expect(output).to include("Dry run — nothing sent")
      expect(stub).not_to have_been_requested
    end

    it "makes no API call when the user declines the confirmation" do
      stub = stub_postmark
      script = [ "1", "Hi {{name}}", "Hello", csv, "1", "2", "n" ].join("\n") + "\n"
      run_wizard(script)

      expect(stub).not_to have_been_requested
    end
  end

  describe "HTML and multi-line messages" do
    around { |example| Dir.chdir(@dir) { example.run } }

    let(:csv) { File.join(@dir, "people.csv") }
    let(:html_file) { File.join(@dir, "letter.html") }
    let(:text_file) { File.join(@dir, "letter.txt") }
    let(:postmark_url) { "https://api.postmarkapp.com/email" }

    before do
      File.write(csv, "name,email\nAnn,ann@x.com\nTom & <b>Jerry</b>,tom@x.com\n")
      File.write(html_file, "<html><body><h1>Hi {{name}}</h1></body></html>\n")
    end

    def capture_postmark
      sent = []
      stub_request(:post, postmark_url)
        .with { |req| sent << JSON.parse(req.body) }
        .to_return(status: 200, body: '{"MessageID":"pm-1","ErrorCode":0}')
      sent
    end

    # Runs the command, returning [error_or_nil, output] so we can also see what was printed before it failed.
    def attempt(args, script = "")
      output = StringIO.new
      prompter = Messengerr::Prompter.new(input: StringIO.new(script), output:)
      command = described_class.new(prompter:, credentials: @credentials)
      error = begin
        command.run([ "--ledger", @ledger, *args ])
        nil
      rescue Messengerr::Error => e
        e
      end
      [ error, output.string ]
    end

    context "with the real Postmark integration" do
      before { @credentials.write(:postmark, "server_token" => "tok", "from" => "me@x.com") }

      it "sends each rendered HTML message with HTML-escaped values and a plain-text subject" do
        sent = capture_postmark
        # method, subject, csv, map {{name}}, contact column, confirm
        script = [ "1", "Hello {{name}}", csv, "1", "2", "y" ].join("\n") + "\n"
        code, output = run_wizard(script, [ "--html", html_file ])

        expect(code).to eq(0)
        expect(output).to include("Message: 1 line(s) from #{html_file}")
        expect(output).not_to include("Message (use {{column}} placeholders):")
        ann, tom = sent
        expect(ann).to include("To" => "ann@x.com", "Subject" => "Hello Ann",
                               "HtmlBody" => "<html><body><h1>Hi Ann</h1></body></html>")
        expect(ann).not_to have_key("TextBody")
        expect(tom["HtmlBody"]).to eq("<html><body><h1>Hi Tom &amp; &lt;b&gt;Jerry&lt;/b&gt;</h1></body></html>")
        expect(tom["HtmlBody"]).not_to include("<b>Jerry")
        expect(tom["Subject"]).to eq("Hello Tom & <b>Jerry</b>") # the subject is plain text, never escaped
      end

      it "previews HTML without dumping markup, writes a browsable preview file, and sends nothing on --dry-run" do
        sent = capture_postmark
        script = [ "1", "Hello {{name}}", csv, "1", "2" ].join("\n") + "\n"
        code, output = run_wizard(script, [ "--html", html_file, "--dry-run" ])

        expect(code).to eq(0)
        expect(sent).to be_empty
        expect(output).to include("Body: HTML, #{"<html><body><h1>Hi Ann</h1></body></html>".length} characters")
        expect(output).not_to include("<h1>")
        preview = File.join(File.realpath(@dir), "messengerr-preview.html") # Dir.pwd resolves symlinks
        expect(output).to include("HTML preview of the first message: #{preview}")
        expect(File.read(preview)).to eq("<html><body><h1>Hi Ann</h1></body></html>")
        expect(File.stat(preview).mode & 0o777).to eq(0o600)
      end

      it "sends a multi-line plain-text message from --message-file, normalising line endings" do
        File.binwrite(text_file, "Hi {{name}},\r\n\r\nSecond paragraph.\r\nBye\r\n\r\n")
        sent = capture_postmark
        script = [ "1", "Note for {{name}}", csv, "1", "2", "y" ].join("\n") + "\n"
        _, output = run_wizard(script, [ "--message-file", text_file ])

        expect(sent.first).to include("TextBody" => "Hi Ann,\n\nSecond paragraph.\nBye")
        expect(sent.first).not_to have_key("HtmlBody")
        expect(output).to include("Message: 4 line(s) from #{text_file}")
        expect(output).to include("Body:\n  Hi Ann,\n  \n  Second paragraph.\n  Bye")
        expect(File.exist?(File.join(@dir, "messengerr-preview.html"))).to be(false)
      end

      it "still aborts when an HTML template leaves a malformed placeholder, before anything is sent" do
        File.write(html_file, "<p>Hi {{first-name}}</p>")
        sent = capture_postmark
        # no {{placeholders}} are recognised in the template, so there is nothing to map: method, subject, csv, contact column
        script = [ "1", "Hello", csv, "2" ].join("\n") + "\n"
        code, output = run_wizard(script, [ "--html", html_file ])

        expect(code).to eq(1)
        expect(output).to include("unrenderable placeholder left in message")
        expect(sent).to be_empty
      end
    end

    it "sends a multi-line SMS from --message-file" do
      @credentials.write(:clicksend, "username" => "u", "api_key" => "k")
      File.write(csv, "name,phone\nAnn,+12025550123\n")
      File.write(text_file, "Hi {{name}}\nYour code is ready")
      body = nil
      stub_request(:post, "https://rest.clicksend.com/v3/sms/send")
        .with { |req| body = JSON.parse(req.body) }
        .to_return(status: 200, body: { data: { messages: [ { message_id: "m1", status: "SUCCESS" } ] } }.to_json)

      script = [ "2", csv, "1", "2", "y" ].join("\n") + "\n"
      code, = run_wizard(script, [ "--message-file", text_file ])

      expect(code).to eq(0)
      expect(body["messages"].first).to include("to" => "+12025550123", "body" => "Hi Ann\nYour code is ready")
    end

    describe "bad input is reported before it can cause harm" do
      it "refuses both flags at once, before any prompt" do
        error, output = attempt([ "--html", html_file, "--message-file", text_file ])

        expect(error.message).to eq("use either --html or --message-file, not both (see `messengerr send --help`)")
        expect(output).to be_empty
      end

      it "refuses a missing file before any prompt" do
        error, output = attempt([ "--html", File.join(@dir, "nope.html") ])

        expect(error.message).to match(/message file not found/)
        expect(output).to be_empty
      end

      it "refuses an empty file before any prompt" do
        File.write(text_file, "  \n\n")
        error, output = attempt([ "--message-file", text_file ])

        expect(error.message).to match(/message file is empty/)
        expect(output).to be_empty
      end

      it "refuses a file that is not UTF-8 before any prompt" do
        File.binwrite(text_file, "Caf\xE9 {{name}}")
        error, output = attempt([ "--message-file", text_file ])

        expect(error.message).to match(/not valid UTF-8/)
        expect(output).to be_empty
      end

      it "accepts a UTF-8 file with a byte-order mark" do
        File.binwrite(text_file, "\xEF\xBB\xBFHi {{name}}")
        @credentials.write(:fake, "token" => "ok")
        script = [ "1", "Sub", csv, "1", "2", "y", "n" ].join("\n") + "\n"
        _, output = run_wizard(script, [ "--message-file", text_file, "--dry-run" ])

        expect(output).to include("Body: Hi Ann")
      end

      it "refuses --html for SMS, right after the delivery method is chosen" do
        error, output = attempt([ "--html", html_file ], "2\n")

        expect(error.message).to match(/--html is only for email/)
        expect(output).not_to include("Message")
      end

      it "refuses --html for an integration that can't send HTML, so markup is never sent as text" do
        @credentials.write(:fake, "token" => "ok") # the Fake integration declares text only
        error, = attempt([ "--html", html_file ], "1\n")

        expect(error.message).to eq("fake can't send HTML email")
      end
    end
  end
end
