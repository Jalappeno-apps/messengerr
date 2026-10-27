require "optparse"

module Messengerr
  class CLI
    BANNER = <<~TEXT
      Usage: messengerr <command>

      Commands:
        credentials  Manage integration credentials (setup|list|verify|delete)
        send         Send a message to a CSV contact list (see `send --help`)
        integrations List registered integrations
    TEXT

    def self.start(argv, prompter: Prompter.new, credentials: Credentials.new, out: $stdout)
      new(prompter:, credentials:, out:).start(argv)
    end

    def initialize(prompter:, credentials:, out: $stdout)
      @prompter = prompter
      @credentials = credentials
      @out = out
    end

    def start(argv)
      command = argv.first

      case command
      when "credentials"
        CLI::CredentialsCommand.new(prompter: @prompter, credentials: @credentials).run(argv[1..])
      when "send"
        CLI::SendCommand.new(prompter: @prompter, credentials: @credentials).run(argv[1..])
      when "integrations"
        CLI::IntegrationsCommand.new(prompter: @prompter, credentials: @credentials).run
      when "-h", "--help", nil
        @out.puts BANNER
        0
      when "-v", "--version"
        @out.puts Messengerr::VERSION
        0
      else
        @out.puts "messengerr: unknown command '#{command}'"
        @out.puts BANNER
        1
      end
    rescue Error => e
      @out.puts "messengerr: #{e.message}"
      1
    end
  end
end
