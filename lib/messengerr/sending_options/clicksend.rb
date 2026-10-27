module Messengerr
  module SendingOptions
    class ClickSend < Base
      MAX_BATCH = 1_000 # ClickSend caps /sms/send at 1000 messages per request

      option :schedule

      def validate!
        super
        if batch_size > MAX_BATCH
          raise ValidationError, "batch_size can't exceed #{MAX_BATCH} for ClickSend"
        end

        true
      end
    end
  end
end
