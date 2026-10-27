require_relative "release_check"
require_relative "../lib/messengerr/version"

namespace :release do
  desc "Fail unless TAG (or GITHUB_REF_NAME) matches the gem version and CHANGELOG.md has a dated entry"
  task :check do
    tag = ENV["TAG"] || ENV["GITHUB_REF_NAME"] || abort("Pass the tag to check: rake release:check TAG=v#{Messengerr::VERSION}")
    problems = ReleaseCheck.problems(version: Messengerr::VERSION, tag:, changelog: File.read("CHANGELOG.md", encoding: "UTF-8"))
    abort("Not ready to release:\n  - #{problems.join("\n  - ")}") unless problems.empty?
    puts "Ready to release #{tag}"
  end

  desc "Print the CHANGELOG.md notes for the current version (used for the GitHub release)"
  task :notes do
    puts ReleaseCheck.notes(version: Messengerr::VERSION, changelog: File.read("CHANGELOG.md", encoding: "UTF-8"))
  end
end
