module Messengerr
  # Per-recipient send outcome.
  Result = Data.define(:recipient, :status, :reason, :provider_id) do
    def initialize(recipient:, status:, reason: nil, provider_id: nil)
      super
    end

    def sent? = status == :sent
  end
end
