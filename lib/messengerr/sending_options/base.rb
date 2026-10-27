module Messengerr
  module SendingOptions
    # Shared sending options every service supports. Subclasses call `option`
    # to add their own; each class validates its values in `validate!`.
    class Base
      class << self
        def option(name)
          options << name
          attr_accessor name
        end

        def options
          @options ||= superclass.respond_to?(:options) ? superclass.options.dup : []
        end
      end

      option :from
      option :batch_size
      option :rate_limit
      option :metadata

      def initialize(attributes = {})
        attributes.each do |key, value|
          public_send("#{key}=", value)
        end
        @batch_size ||= 50
        @rate_limit ||= 10
        @metadata ||= {}
      end

      def validate!
        errors = []
        errors << "batch_size must be a positive integer" unless batch_size.is_a?(Integer) && batch_size.positive?
        errors << "rate_limit must be positive" unless rate_limit.is_a?(Numeric) && rate_limit.positive?
        raise ValidationError, errors.join(", ") unless errors.empty?

        true
      end

      def to_h
        self.class.options.to_h { |name| [ name, public_send(name) ] }
      end
    end
  end
end
