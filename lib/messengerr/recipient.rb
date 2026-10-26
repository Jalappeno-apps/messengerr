module Messengerr
  # One sendable contact: normalized contact value plus its source row data.
  Recipient = Data.define(:contact, :row, :row_number)
end
