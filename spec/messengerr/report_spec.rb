RSpec.describe Messengerr::Report do
  let(:recipient) { Messengerr::Recipient.new(contact: "a@x.com", row: {}, row_number: 2) }
  let(:defect) { Messengerr::ContactValidator::Defect.new(row_number: 3, value: "x", reason: "invalid email address") }

  it "aggregates successes, failures, and drops" do
    report = described_class.new(
      results: [
        Messengerr::Result.new(recipient:, status: :sent),
        Messengerr::Result.new(recipient:, status: :failed, reason: "boom")
      ],
      dropped: [defect]
    )

    expect(report.sent_count).to eq(1)
    expect(report.failed_count).to eq(1)
    expect(report.dropped_count).to eq(1)
    expect(report).not_to be_ok
    expect(report.summary).to eq("sent: 1, failed: 1, dropped: 1")
  end

  it "is ok when nothing failed" do
    report = described_class.new(results: [Messengerr::Result.new(recipient:, status: :sent)])
    expect(report).to be_ok
  end
end
