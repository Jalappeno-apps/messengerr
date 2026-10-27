require "tmpdir"

RSpec.describe Messengerr::Ledger do
  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      @path = File.join(dir, "nested", "ledger.jsonl")
      example.run
    end
  end

  def result(contact, status, uncertain: false, row: 2)
    Messengerr::Result.new(
      recipient: Messengerr::Recipient.new(contact:, row: {}, row_number: row),
      status:, reason: (status == :failed ? "boom" : nil), uncertain:
    )
  end

  it "creates the ledger owner-only (it holds every contact)" do
    ledger = described_class.new(@path)
    ledger.record(result("a@x.com", :sent))

    expect(File.stat(@path).mode & 0o777).to eq(0o600)
  end

  it "does not touch the filesystem until used" do
    described_class.new(@path)
    expect(File.exist?(File.dirname(@path))).to be(false)
  end

  it "appends one JSON line per result" do
    ledger = described_class.new(@path)
    ledger.record(result("a@x.com", :sent))
    ledger.record(result("b@x.com", :failed, uncertain: true, row: 3))

    entries = File.readlines(@path).map { |l| JSON.parse(l) }
    expect(entries.map { |e| e["contact"] }).to eq(%w[a@x.com b@x.com])
    expect(entries.last).to include("status" => "failed", "uncertain" => true, "row_number" => 3)
  end

  describe "#verify_writable!" do
    it "creates the ledger up front" do
      described_class.new(@path).verify_writable!
      expect(File.exist?(@path)).to be(true)
    end

    it "raises a clear Error when the path can't be written" do
      skip "root can write anywhere" if Process.uid.zero?
      FileUtils.mkdir_p(File.join(@dir, "ro"))
      File.chmod(0o500, File.join(@dir, "ro"))
      ledger = described_class.new(File.join(@dir, "ro", "ledger.jsonl"))

      expect { ledger.verify_writable! }.to raise_error(Messengerr::Error, /cannot write ledger/)
    ensure
      File.chmod(0o700, File.join(@dir, "ro"))
    end
  end

  describe "reading outcomes" do
    before do
      ledger = described_class.new(@path)
      ledger.record(result("sent@x.com", :sent, row: 2))
      ledger.record(result("rejected@x.com", :failed, row: 3))
      ledger.record(result("maybe@x.com", :failed, uncertain: true, row: 4))
      ledger.record(result("recovered@x.com", :failed, uncertain: true, row: 5))
      ledger.record(result("recovered@x.com", :sent, row: 5))
      File.open(@path, "a") { |f| f.write('{"contact":"torn@x.com","sta') } # crash mid-write
    end

    it "lists recipients sent, as [row_number, contact]" do
      expect(described_class.sent_recipients(@path))
        .to contain_exactly([2, "sent@x.com"], [5, "recovered@x.com"])
    end

    it "lists recipients whose last outcome is uncertain, ignoring ones later sent" do
      expect(described_class.uncertain_recipients(@path)).to eq([[4, "maybe@x.com"]])
    end

    it "treats a missing file as empty" do
      expect(described_class.sent_recipients(File.join(@dir, "nope"))).to eq([])
      expect(described_class.uncertain_recipients(File.join(@dir, "nope"))).to eq([])
    end
  end

  describe "repeated contacts" do
    it "tracks each row separately: a send to row 2 says nothing about row 5" do
      ledger = described_class.new(@path)
      ledger.record(result("dup@x.com", :sent, row: 2))
      ledger.record(result("dup@x.com", :failed, uncertain: true, row: 5))

      expect(described_class.sent_recipients(@path)).to eq([[2, "dup@x.com"]])
      expect(described_class.uncertain_recipients(@path)).to eq([[5, "dup@x.com"]])
    end
  end
end
