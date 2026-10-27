module Messengerr
  # One fully-rendered outbound message: who it goes to, the body, and an
  # optional per-recipient subject (email).
  Delivery = Data.define(:recipient, :body, :subject)
end
