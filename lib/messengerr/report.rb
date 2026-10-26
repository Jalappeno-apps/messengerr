module Messengerr
  # Aggregate outcome of a send run: Results plus dropped validation defects.
  class Report
    attr_reader :results, :dropped

    def initialize(results: [], dropped: [])
      @results = results
      @dropped = dropped # validation defects the user chose to drop
    end

    def successes = @results.select(&:sent?)
    def failures = @results.reject(&:sent?)

    def sent_count = successes.length
    def failed_count = failures.length
    def dropped_count = @dropped.length

    def ok? = failures.empty?

    def summary
      "sent: #{sent_count}, failed: #{failed_count}, dropped: #{dropped_count}"
    end
  end
end
