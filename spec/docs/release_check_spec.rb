require_relative "../../rakelib/release_check"

RSpec.describe ReleaseCheck do
  let(:changelog) do
    <<~MD
      # Changelog

      ## 0.2.0 (2026-11-01)

      - Newer thing.

      ## 0.1.0 (2026-10-28)

      First release.
      - A
      - B
    MD
  end

  describe ".problems" do
    it "is empty when the tag matches and the changelog entry is dated" do
      expect(described_class.problems(version: "0.1.0", tag: "v0.1.0", changelog:)).to eq([])
    end

    it "refuses a tag that does not match the gem version" do
      problems = described_class.problems(version: "0.1.0", tag: "v0.1.1", changelog:)

      expect(problems).to contain_exactly(a_string_matching(/does not match.*expected v0\.1\.0/))
    end

    it "refuses a tag without the v prefix" do
      expect(described_class.problems(version: "0.1.0", tag: "0.1.0", changelog:)).not_to be_empty
    end

    it "refuses a version with no changelog entry" do
      expect(described_class.problems(version: "0.3.0", tag: "v0.3.0", changelog:))
        .to contain_exactly("CHANGELOG.md has no entry for 0.3.0")
    end

    it "refuses an entry still marked unreleased" do
      unreleased = changelog.sub("## 0.1.0 (2026-10-28)", "## 0.1.0 (unreleased)")

      expect(described_class.problems(version: "0.1.0", tag: "v0.1.0", changelog: unreleased))
        .to contain_exactly(a_string_matching(/still marks 0\.1\.0 as unreleased/))
    end

    it "reports every problem at once" do
      expect(described_class.problems(version: "0.3.0", tag: "v9", changelog:).length).to eq(2)
    end

    it "does not mistake a different version that merely starts the same (0.10.0) for 0.1.0" do
      only_longer = "## 0.10.0 (2026-10-28)\n\nx\n"

      expect(described_class.problems(version: "0.1.0", tag: "v0.1.0", changelog: only_longer))
        .to include("CHANGELOG.md has no entry for 0.1.0")
    end
  end

  describe ".notes" do
    it "returns only the requested version's section, without its heading" do
      expect(described_class.notes(version: "0.1.0", changelog:)).to eq("First release.\n- A\n- B")
      expect(described_class.notes(version: "0.2.0", changelog:)).to eq("- Newer thing.")
    end

    it "raises when the version has no entry" do
      expect { described_class.notes(version: "9.9.9", changelog:) }.to raise_error(/no entry for 9\.9\.9/)
    end
  end
end
