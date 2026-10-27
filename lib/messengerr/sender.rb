module Messengerr
  # Dispatches Deliveries through an integration in batch_size slices,
  # throttled by rate_limit. Every delivery produces exactly one Result:
  # exceptions become failed Results, and integrations that return too few
  # results get the gaps filled rather than silently losing contacts.
  #
  # Integrations that send one message at a time may yield each Result from
  # send_batch as it lands; the Sender records those to the ledger immediately,
  # so a crash or Ctrl-C mid-batch never loses what was already delivered.
  class Sender
    # Why the run stopped early, if it did (currently: the ledger became
    # unwritable, so no further batch is sent without a record).
    attr_reader :halted_reason

    def initialize(integration, options: integration.class.options_class.new, ledger: nil)
      @integration = integration
      @options = options
      @options.validate!
      @ledger = ledger
      @recorded = {}
      @halted_reason = nil
    end

    # deliveries → [Result], one per delivery, in slice order.
    def deliver(deliveries)
      deliveries.each_slice(@options.batch_size).with_index.flat_map do |slice, index|
        throttle if index.positive? && !@halted_reason
        @halted_reason ? halted_results(slice) : dispatch(slice)
      end
    end

    private

    def dispatch(slice)
      @recorded = {} # dedupe is per batch: a retry must be recorded again
      seen = {}
      results =
        begin
          returned = @integration.send_batch(slice, @options) do |result|
            seen[key(result.recipient)] = result
            record(result)
          end
          reconcile(slice, returned, seen)
        rescue Interrupt
          # Whatever hadn't reported back may or may not have gone out.
          slice.each { |d| record(seen[key(d.recipient)] || failure(d, "interrupted", uncertain: true)) }
          raise
        rescue StandardError => e
          failure_results(slice, seen, e)
        end

      results.each { |r| record(r) }
      results
    end

    # One Result per delivery. Results the integration yielded survive an
    # exception raised later in the same batch.
    def failure_results(slice, seen, error)
      # A plain IntegrationError means the provider definitely rejected it;
      # anything else (timeouts, UncertainError, bugs) may have gone out.
      uncertain = !(error.is_a?(IntegrationError) && !error.is_a?(UncertainError))
      slice.map { |d| seen[key(d.recipient)] || failure(d, error.message, uncertain:) }
    end

    # The contract: one Result per delivery. Gaps are filled with uncertain
    # failures rather than silently dropping contacts.
    def reconcile(slice, returned, seen)
      by_recipient = Array(returned).group_by { |r| key(r.recipient) }
      slice.map do |d|
        k = key(d.recipient)
        by_recipient[k]&.first || seen[k] || failure(d, "integration returned no result", uncertain: true)
      end
    end

    def failure(delivery, reason, uncertain: false)
      Result.new(recipient: delivery.recipient, status: :failed, reason:, uncertain:)
    end

    def halted_results(slice)
      slice.map { |d| failure(d, "not sent — #{@halted_reason}") }
    end

    def record(result)
      return unless @ledger

      k = key(result.recipient)
      return if @recorded[k]

      @ledger.record(result)
      @recorded[k] = true
    rescue SystemCallError, IOError => e
      # Never crash after a send: keep the in-memory result, stop sending more.
      @halted_reason ||= "ledger write failed (#{e.message}); stopped so no message goes unrecorded"
    end

    def key(recipient)
      [ recipient.row_number, recipient.contact ]
    end

    def throttle
      sleep(1.0 / @options.rate_limit)
    end
  end
end
