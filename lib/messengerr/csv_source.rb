require "csv"

module Messengerr
  # Local CSV file → headers + string-keyed row hashes.
  class CsvSource
    attr_reader :headers, :rows

    def self.from(path)
      expanded = File.expand_path(path)
      raise Error, "CSV file not found: #{path}" unless File.file?(expanded)

      table = CSV.read(expanded, headers: true, encoding: "bom|utf-8")
      headers = table.headers.compact
      raise Error, "CSV has no header row: #{path}" if headers.empty?

      duplicates = headers.tally.select { |_, count| count > 1 }.keys
      unless duplicates.empty?
        raise Error, "CSV has duplicate headers: #{duplicates.join(', ')}"
      end

      new(headers: table.headers, rows: table.map(&:to_h))
    rescue CSV::MalformedCSVError, Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError => e
      raise Error, "could not parse CSV #{path}: #{e.message}"
    end

    def initialize(headers:, rows:)
      @headers = headers
      @rows = rows
    end
  end
end
