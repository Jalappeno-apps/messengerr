require "json"
require "fileutils"
require "time"

module Messengerr
  # Durable record of send outcomes, one JSONL line per Result, appended as
  # each result lands so a crash mid-run loses nothing already delivered —
  # and `--resume` can skip contacts already marked sent. It holds every
  # contact's address/number, so it is created owner-only (0600).
  class Ledger
    def initialize(path)
      @path = path
    end

    # Fail before anything is sent if the ledger can't be written.
    def verify_writable!
      FileUtils.mkdir_p(File.dirname(@path))
      File.open(@path, "a", 0o600) { }
    rescue SystemCallError, IOError => e
      raise Error, "cannot write ledger #{@path}: #{e.message}"
    end

    def record(result)
      FileUtils.mkdir_p(File.dirname(@path))
      File.open(@path, "a", 0o600) do |file|
        file.puts(JSON.dump(
          row_number: result.recipient.row_number,
          contact: result.recipient.contact,
          status: result.status,
          reason: result.reason,
          provider_id: result.provider_id,
          uncertain: result.uncertain,
          sent_at: Time.now.utc.iso8601
        ))
        file.flush
      end
    end

    # Recipients already sent per this ledger — used by --resume. A recipient
    # is [row_number, contact]: repeated contacts are separate messages, so
    # sending row 2 to a@x.com says nothing about row 5 to the same address.
    def self.sent_recipients(path)
      outcomes(path).select { |_, state| state == :sent }.keys
    end

    # Recipients whose last attempt failed *uncertainly* and never later
    # succeeded: they may already have received the message.
    def self.uncertain_recipients(path)
      outcomes(path).select { |_, state| state == :uncertain }.keys
    end

    def self.default_path
      File.join(Dir.pwd, "messengerr-ledger-#{Time.now.utc.strftime('%Y%m%d-%H%M%S')}.jsonl")
    end

    # [row_number, contact] → :sent | :uncertain | :failed. :sent is terminal.
    def self.outcomes(path)
      return {} unless File.exist?(path)

      File.readlines(path).each_with_object({}) do |line, states|
        entry = JSON.parse(line)
        next if entry["contact"].nil?

        recipient = [ entry["row_number"], entry["contact"] ]
        next if states[recipient] == :sent

        states[recipient] =
          if entry["status"] == "sent" then :sent
          elsif entry["uncertain"] then :uncertain
          else :failed
          end
      rescue JSON::ParserError
        next # a torn final line from a crash
      end
    end
    private_class_method :outcomes
  end
end
