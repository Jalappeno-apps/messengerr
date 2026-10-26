module Messengerr
  # Renders the message per recipient and dispatches batches through an
  # integration, honoring batch_size and rate_limit. Render failures and
  # batch send failures become failed Results — sending always continues.
  class Sender
    def initialize(integration, options: integration.class.options_class.new)
      @integration = integration
      @options = options
      @options.validate!
    end

    # → [Result] in recipient order of appearance per group.
    def send(recipients, template, mapping)
      pairs, failures = prepare(recipients, template, mapping)

      results = failures
      pairs.each_slice(@options.batch_size).with_index do |slice, index|
        throttle if index.positive?
        results.concat(dispatch(slice))
      end
      results
    end

    private

    # → [[recipient, rendered_message], ...] + failed Results for unrenderable rows.
    def prepare(recipients, template, mapping)
      prepared = []
      failures = []

      recipients.each do |recipient|
        prepared << [recipient, Renderer.render(template, recipient.row, mapping)]
      rescue RenderError => e
        failures << Result.new(recipient:, status: :failed, reason: e.message)
      end

      [prepared, failures]
    end

    def dispatch(slice)
      @integration.send_batch(slice, @options)
    rescue IntegrationError => e
      slice.map { |recipient, _| Result.new(recipient:, status: :failed, reason: e.message) }
    end

    def throttle
      sleep(1.0 / @options.rate_limit)
    end
  end
end
