module Messengerr
  class Error < StandardError; end
  class CredentialsError < Error; end
  class IntegrationError < Error; end
  # The provider may have accepted the request (timeout after sending, 5xx,
  # unreadable response). Retrying can duplicate the message.
  class UncertainError < IntegrationError; end
  class ValidationError < Error; end
  class RenderError < Error; end
end
