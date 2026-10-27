module Messengerr
  module SendingOptions
    class Postmark < Base
      # `subject` is a fallback only; the wizard supplies a (rendered) subject
      # per Delivery, and the integration fails any delivery that has neither.
      option :subject
      option :message_stream
      option :tag
      option :track_opens
    end
  end
end
