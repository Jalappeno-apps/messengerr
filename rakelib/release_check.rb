# Release guards, shared by `rake release:check`, `rake release:notes` and the Release workflow,
# so the rules are testable and identical on a laptop and in CI.
module ReleaseCheck
  # → [String] problems that must be fixed before this tag may be published (empty = OK).
  def self.problems(version:, tag:, changelog:)
    problems = []
    problems << "tag #{tag.inspect} does not match lib/messengerr/version.rb (expected v#{version})" unless tag == "v#{version}"

    heading = heading_for(version, changelog)
    if heading.nil?
      problems << "CHANGELOG.md has no entry for #{version}"
    elsif heading.include?("unreleased")
      problems << "CHANGELOG.md still marks #{version} as unreleased (give it a release date)"
    end
    problems
  end

  # The changelog section for `version`, without its heading, for the GitHub release body.
  def self.notes(version:, changelog:)
    lines = changelog.lines
    start = lines.index { |line| line.start_with?("## #{version}") }
    raise "CHANGELOG.md has no entry for #{version}" unless start

    lines[(start + 1)..].take_while { |line| !line.start_with?("## ") }.join.strip
  end

  def self.heading_for(version, changelog)
    changelog.lines.find { |line| line.start_with?("## #{version}") }
  end
end
