module Messengerr
  class Error < StandardError; end
  class CredentialsError < Error; end
  class IntegrationError < Error; end
  class ValidationError < Error; end
  class RenderError < Error; end
end
