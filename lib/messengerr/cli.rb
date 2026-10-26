require "optparse"

module Messengerr
  class CLI
    def self.start(argv, out: $stdout)
      new(out:).start(argv)
    end

    def initialize(out: $stdout)
      @out = out
    end

    def start(argv)
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: messengerr <command>\n\nCommands:\n" \
                      "  credentials  Manage integration credentials\n" \
                      "  send         Send a message to a CSV contact list\n" \
                      "  integrations List registered integrations"
        opts.version = Messengerr::VERSION
        opts.on("-h", "--help") { @out.puts opts; return 0 }
      end
      parser.parse(argv)
      @out.puts parser
      0
    rescue OptionParser::ParseError => e
      @out.puts "messengerr: #{e.message}"
      1
    end
  end
end
