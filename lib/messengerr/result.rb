module Messengerr
  # Per-recipient send outcome. `uncertain` marks failures where the provider
  # may still have delivered (timeouts, unreadable responses) — retrying these
  # can duplicate the message.
  Result = Data.define(:recipient, :status, :reason, :provider_id, :uncertain) do
    def initialize(recipient:, status:, reason: nil, provider_id: nil, uncertain: false)
      super
    end

    def sent? = status == :sent
  end
end
