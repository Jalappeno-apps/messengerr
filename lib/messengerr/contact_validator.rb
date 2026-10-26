require "uri"
require "phonelib"

module Messengerr
  # Validates contact values for a delivery method. Returns valid Recipients
  # and a list of defects the user can inspect, then drop or abort on.
  module ContactValidator
    Defect = Data.define(:row_number, :value, :reason)

    def self.validate(rows, contact_column, delivery_method)
      Phonelib.default_country ||= ENV["MESSENGERR_DEFAULT_COUNTRY"] if delivery_method == :sms

      valid = []
      defects = []
      rows.each_with_index do |row, index|
        row_number = index + 2 # header is line 1
        raw = row[contact_column]
        case check(raw, delivery_method)
        in [:ok, normalized]
          valid << Recipient.new(contact: normalized, row:, row_number:)
        in [:defect, reason]
          defects << Defect.new(row_number:, value: raw, reason:)
        end
      end
      { valid:, defects: }
    end

    def self.check(value, delivery_method)
      return [:defect, "empty value"] if value.nil? || value.strip.empty?

      case delivery_method
      when :email
        value.strip.match?(URI::MailTo::EMAIL_REGEXP) ? [:ok, value.strip.downcase] : [:defect, "invalid email address"]
      when :sms
        phone = Phonelib.parse(value.strip)
        phone.valid? ? [:ok, phone.e164] : [:defect, "invalid phone number"]
      else
        raise Error, "unknown delivery method: #{delivery_method}"
      end
    end
  end
end
