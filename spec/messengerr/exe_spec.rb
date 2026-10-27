require "open3"
require "pty"
require "tmpdir"
require "timeout"

# Runs the real executable as a separate process, so these cover what in-process
# specs cannot: how the terminal check behaves with a real stdin (a pipe vs a
# pseudo-terminal). No network is touched: every path below stops at the
# preview/confirmation before anything would be sent.
RSpec.describe "exe/messengerr send (real process)" do
  let(:exe) { File.expand_path("../../exe/messengerr", __dir__) }
  let(:lib) { File.expand_path("../../lib", __dir__) }

  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      Messengerr::Credentials.new(
        credentials_path: File.join(dir, "credentials.yml.enc"), key_path: File.join(dir, "master.key")
      ).write(:postmark, "server_token" => "tok", "from" => "me@x.com")
      File.write(File.join(dir, "people.csv"), "name,email\nAnn,ann@x.com\n")
      example.run
    end
  end

  def env = { "MESSENGERR_CONFIG_DIR" => @dir, "MESSENGERR_MASTER_KEY" => nil }

  def send_args(*extra)
    [ "send", "--method", "email", "--csv", File.join(@dir, "people.csv"), "--contact", "email",
      "--map", "name=name", "--message", "Hi {{name}}", "--subject", "Hello", "--ledger", File.join(@dir, "l.jsonl"), *extra ]
  end

  # The child writes UTF-8 (em dashes); captured pipes come back as raw bytes.
  def run_piped(args, stdin: "")
    out, err, status = Open3.capture3(env, RbConfig.ruby, "-I", lib, exe, *args, stdin_data: stdin, chdir: @dir)
    [ out.force_encoding(Encoding::UTF_8), err.force_encoding(Encoding::UTF_8), status ]
  end

  describe "with a pipe for standard input (how an agent shell or CI runs it)" do
    it "refuses a real send, exits 1, and leaves no ledger" do
      out, _err, status = run_piped(send_args)

      expect(status.exitstatus).to eq(1)
      expect(out).to include("messengerr: refusing to send without an interactive terminal")
      expect(File.exist?(File.join(@dir, "l.jsonl"))).to be(false)
    end

    it "still allows --dry-run, which sends nothing" do
      out, _err, status = run_piped(send_args("--dry-run"))

      expect(status.exitstatus).to eq(0)
      expect(out).to include("To: ann@x.com")
      expect(out).to include("Dry run — nothing sent")
      expect(File.exist?(File.join(@dir, "l.jsonl"))).to be(false)
    end

    it "gets past the guard with --allow-non-interactive, then stops at the confirmation when declined" do
      out, _err, status = run_piped(send_args("--allow-non-interactive"), stdin: "n\n")

      expect(out).not_to include("refusing to send")
      expect(out).to include("Send 1 message(s)?")
      expect(out).to include("Aborted — nothing was sent.")
      expect(status.exitstatus).to eq(1)
    end
  end

  describe "with a real terminal (a person at a keyboard)" do
    # The guard must never get in a human's way. A pseudo-terminal gives the
    # child a real TTY on stdin, exactly like a terminal window does.
    it "is not refused: it reaches the confirmation, and declining sends nothing" do
      output = +""
      status = nil
      PTY.spawn(env, RbConfig.ruby, "-I", lib, exe, *send_args, chdir: @dir) do |reader, writer, pid|
        Timeout.timeout(20) do
          loop do
            chunk = reader.readpartial(4096)
            output << chunk
            if output.include?("Send 1 message(s)?") && !output.include?("[y/n] n")
              writer.puts("n")
            end
          end
        rescue Errno::EIO, EOFError
          nil
        end
        _, status = Process.wait2(pid)
      end

      output.force_encoding(Encoding::UTF_8)
      expect(output).not_to include("refusing to send")
      expect(output).to include("Send 1 message(s)?")
      expect(output).to include("Aborted — nothing was sent.")
      expect(status.exitstatus).to eq(1)
      expect(File.exist?(File.join(@dir, "l.jsonl"))).to be(false)
    end
  end
end
