require_relative "lib/messengerr/version"

Gem::Specification.new do |spec|
  spec.name          = "messengerr"
  spec.version       = Messengerr::VERSION
  spec.authors       = [ "Daiwick" ]
  spec.email         = [ "developers@daiwick.com" ]
  spec.summary       = "Send templated messages to CSV contact lists over email and SMS."
  spec.description   = "Interactive CLI that renders {{placeholder}} messages against a CSV " \
                       "contact list and dispatches through pluggable services scoped by " \
                       "delivery method (email, sms)."
  spec.homepage      = "https://github.com/jalappeno-apps/messengerr"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.2"
  spec.metadata = {
    "documentation_uri" => "https://jalappeno-apps.github.io/messengerr/",
    "source_code_uri" => "https://github.com/jalappeno-apps/messengerr",
    "bug_tracker_uri" => "https://github.com/jalappeno-apps/messengerr/issues",
    "changelog_uri" => "https://github.com/jalappeno-apps/messengerr/blob/main/CHANGELOG.md",
    "rubygems_mfa_required" => "true",
    "allowed_push_host" => "https://rubygems.org"
  }

  spec.files = Dir["lib/**/*", "exe/*", "README.md", "LICENSE"]
  spec.bindir = "exe"
  spec.executables = [ "messengerr" ]
  spec.require_paths = [ "lib" ]

  spec.add_dependency "base64", "~> 0.2"
  spec.add_dependency "csv", "~> 3.3"
  spec.add_dependency "phonelib", "~> 0.8"
  spec.add_dependency "postmark", "~> 1.25"
  spec.add_dependency "zeitwerk", "~> 2.6"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "webmock", "~> 3.23"
end
