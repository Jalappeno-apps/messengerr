module Messengerr
  # One fully-rendered outbound message: who it goes to, the body, and an
  # optional per-recipient subject (email). `format` says how to read `body`:
  # :text (the default) or :html. Only integrations that declare :html in
  # `.formats` are ever handed an :html delivery.
  Delivery = Data.define(:recipient, :body, :subject, :format) do
    def initialize(recipient:, body:, subject:, format: :text)
      raise ArgumentError, "unknown delivery format: #{format.inspect}" unless %i[text html].include?(format)

      super
    end

    def html? = format == :html
  end
end
