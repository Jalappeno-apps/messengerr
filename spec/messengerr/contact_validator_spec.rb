RSpec.describe Messengerr::ContactValidator do
  let(:rows) { Messengerr::CsvSource.from(File.expand_path("../fixtures/contacts.csv", __dir__)).rows }

  it "validates emails, collecting valid recipients and defects" do
    outcome = described_class.validate(rows, "email", :email)

    expect(outcome[:valid].map(&:contact)).to include("alice@example.com", "bob@example.com")
    reasons = outcome[:defects].map(&:reason)
    expect(reasons).to include("invalid email address", "empty value")
  end

  it "normalizes phones to E.164" do
    outcome = described_class.validate(rows, "phone", :sms)

    expect(outcome[:valid].map(&:contact)).to include("+12025550123")
    defect_values = outcome[:defects].map(&:value)
    expect(defect_values).to include("123", nil)
  end

  it "tracks 1-based row numbers offset by the header" do
    rows = [ { "email" => "bad" } ]
    outcome = described_class.validate(rows, "email", :email)
    expect(outcome[:defects].first.row_number).to eq(2)
  end

  it "carries the source row on recipients" do
    outcome = described_class.validate(rows, "email", :email)
    expect(outcome[:valid].first.row["name"]).to eq("Alice")
  end

  it "rejects unknown delivery methods" do
    expect { described_class.validate(rows, "email", :fax) }
      .to raise_error(Messengerr::Error, /unknown delivery method/)
  end

  it "keeps repeated contacts: one row is one message" do
    rows = [ { "e" => "a@x.com" }, { "e" => "A@x.com" }, { "e" => " a@x.com " } ]
    outcome = described_class.validate(rows, "e", :email)

    expect(outcome[:valid].map(&:contact)).to eq(%w[a@x.com a@x.com a@x.com])
    expect(outcome[:valid].map(&:row_number)).to eq([ 2, 3, 4 ])
    expect(outcome[:defects]).to be_empty
  end
end
