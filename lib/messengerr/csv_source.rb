require "csv"

module Messengerr
  # Local CSV file → headers + string-keyed row hashes.
  class CsvSource
    attr_reader :headers, :rows

    def self.from(path)
      raise Error, "CSV file not found: #{path}" unless File.exist?(path)

      table = CSV.read(path, headers: true)
      raise Error, "CSV has no header row: #{path}" if table.headers.empty? || table.headers.all?(&:nil?)

      new(headers: table.headers, rows: table.map(&:to_h))
    rescue CSV::MalformedCSVError => e
      raise Error, "could not parse CSV #{path}: #{e.message}"
    end

    def initialize(headers:, rows:)
      @headers = headers
      @rows = rows
    end
  end
end
