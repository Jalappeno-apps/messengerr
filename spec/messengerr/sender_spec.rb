require "tmpdir"
require "json"

RSpec.describe Messengerr::Sender do
  let(:integration) { Messengerr::Integrations::Fake.new({}) }
  let(:deliveries) do
    [
      { "email" => "a@x.com" },
      { "email" => "b@x.com", "fail" => "yes" },
      { "email" => "c@x.com" }
    ].each_with_index.map do |row, i|
      Messengerr::Delivery.new(
        recipient: Messengerr::Recipient.new(contact: row["email"], row:, row_number: i + 2),
        body: "hi", subject: nil
      )
    end
  end

  it "returns one Result per delivery" do
    results = described_class.new(integration, options: opts).deliver(deliveries)
    expect(results.length).to eq(3)
    expect(results.map(&:status)).to eq(%i[sent failed sent])
  end

  it "splits sends into batch_size slices" do
    calls = []
    spy = Class.new(Messengerr::Integrations::Fake) do
      define_method(:send_batch) do |slice, _options|
        calls << slice
        super(slice, _options)
      end
    end.new({})

    described_class.new(spy, options: opts(batch_size: 1)).deliver(deliveries)
    expect(calls.map(&:length)).to eq([ 1, 1, 1 ])
  end

  it "marks a batch failed+uncertain when the integration raises" do
    failing = Class.new(Messengerr::Integrations::Fake) do
      def send_batch(_slice, _options)
        raise Errno::ECONNRESET, "connection reset"
      end
    end.new({})

    results = described_class.new(failing, options: opts).deliver(deliveries)
    expect(results.map(&:status).uniq).to eq([ :failed ])
    expect(results.map(&:uncertain).uniq).to eq([ true ])
    expect(results.first.reason).to include("connection reset")
  end

  it "reconciles integrations that return too few results" do
    short = Class.new(Messengerr::Integrations::Fake) do
      def send_batch(_slice, _options)
        []
      end
    end.new({})

    results = described_class.new(short, options: opts).deliver(deliveries)
    expect(results.map(&:reason).uniq).to eq([ "integration returned no result" ])
  end

  it "records every result to the ledger" do
    require "tmpdir"
    Dir.mktmpdir do |dir|
      path = File.join(dir, "ledger.jsonl")
      ledger = Messengerr::Ledger.new(path)
      described_class.new(integration, options: opts, ledger:).deliver(deliveries)

      lines = File.readlines(path)
      expect(lines.length).to eq(3)
      entry = JSON.parse(lines[1])
      expect(entry).to include("contact" => "b@x.com", "status" => "failed", "reason" => "fake send failure")
    end
  end

  describe "ledger durability (N1)" do
    # Sends one by one and yields each Result, like Postmark.
    def yielding_integration(fail_at: nil, error: nil)
      Class.new(Messengerr::Integrations::Fake) do
        define_method(:send_batch) do |slice, _options, &on_result|
          slice.each_with_index.map do |d, i|
            raise error if i == fail_at

            Messengerr::Result.new(recipient: d.recipient, status: :sent, provider_id: "p#{i}").tap { |r| on_result&.call(r) }
          end
        end
      end.new({})
    end

    def ledger_in(dir) = Messengerr::Ledger.new(File.join(dir, "l.jsonl"))
    def lines(dir) = File.readlines(File.join(dir, "l.jsonl")).map { |l| JSON.parse(l) }

    it "records each delivery as it is sent, so an Interrupt mid-batch loses nothing" do
      Dir.mktmpdir do |dir|
        sender = described_class.new(yielding_integration(fail_at: 2, error: Interrupt), options: opts, ledger: ledger_in(dir))

        expect { sender.deliver(deliveries) }.to raise_error(Interrupt)

        entries = lines(dir)
        expect(entries.length).to eq(3)
        expect(entries.map { |e| e["status"] }).to eq(%w[sent sent failed])
        expect(entries.last).to include("uncertain" => true, "reason" => "interrupted")
      end
    end

    it "keeps already-sent results when an exception hits later in the same batch" do
      Dir.mktmpdir do |dir|
        sender = described_class.new(yielding_integration(fail_at: 2, error: Errno::ECONNRESET), options: opts, ledger: ledger_in(dir))
        results = sender.deliver(deliveries)

        expect(results.map(&:status)).to eq(%i[sent sent failed])
        expect(results.map(&:uncertain)).to eq([ false, false, true ])
        expect(lines(dir).map { |e| e["status"] }).to eq(%w[sent sent failed])
      end
    end

    it "does not double-record results that were both yielded and returned" do
      Dir.mktmpdir do |dir|
        described_class.new(yielding_integration, options: opts, ledger: ledger_in(dir)).deliver(deliveries)
        expect(lines(dir).length).to eq(3)
      end
    end

    it "records a retry's result again" do
      Dir.mktmpdir do |dir|
        sender = described_class.new(integration, options: opts, ledger: ledger_in(dir))
        sender.deliver(deliveries)
        sender.deliver([ deliveries[1] ])

        expect(lines(dir).count { |e| e["contact"] == "b@x.com" }).to eq(2)
      end
    end
  end

  describe "ledger failures (N2)" do
    it "does not crash after sending when the ledger can't be written; it stops further batches" do
      broken = instance_double(Messengerr::Ledger)
      allow(broken).to receive(:record).and_raise(Errno::ENOSPC)
      sender = described_class.new(integration, options: opts(batch_size: 1), ledger: broken)

      results = sender.deliver(deliveries)

      expect(results.length).to eq(3)
      expect(results.first).to be_sent # first batch really went out and is kept
      expect(results.drop(1).map(&:reason)).to all(match(/not sent — ledger write failed/))
      expect(results.drop(1).map(&:uncertain)).to all(be(false))
      expect(sender.halted_reason).to match(/ledger write failed/)
    end
  end

  describe "uncertainty classification (N3)" do
    def raising(error)
      Class.new(Messengerr::Integrations::Fake) { define_method(:send_batch) { |*| raise error } }.new({})
    end

    it "treats a plain IntegrationError (provider rejected it) as a definite failure" do
      results = described_class.new(raising(Messengerr::IntegrationError.new("bad key")), options: opts).deliver(deliveries)
      expect(results.map(&:uncertain).uniq).to eq([ false ])
    end

    it "treats UncertainError as uncertain" do
      results = described_class.new(raising(Messengerr::UncertainError.new("timeout")), options: opts).deliver(deliveries)
      expect(results.map(&:uncertain).uniq).to eq([ true ])
    end

    it "treats unexpected exceptions as uncertain" do
      results = described_class.new(raising(RuntimeError.new("bug")), options: opts).deliver(deliveries)
      expect(results.map(&:uncertain).uniq).to eq([ true ])
    end

    it "marks recipients an integration forgot to report as uncertain" do
      short = Class.new(Messengerr::Integrations::Fake) { def send_batch(*) = [] }.new({})
      results = described_class.new(short, options: opts).deliver(deliveries)
      expect(results.map(&:uncertain).uniq).to eq([ true ])
    end
  end

  def opts(batch_size: 50)
    Messengerr::SendingOptions::Base.new(batch_size:, rate_limit: 1000)
  end
end
