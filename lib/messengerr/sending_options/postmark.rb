module Messengerr
  module SendingOptions
    class Postmark < Base
      option :subject
      option :message_stream
      option :tag
      option :track_opens

      def validate!
        super
        raise ValidationError, "subject is required for email sends" if subject.to_s.strip.empty?

        true
      end
    end
  end
end
