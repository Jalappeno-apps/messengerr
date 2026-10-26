module Messengerr
  class CLI
    # messengerr send — interactive wizard:
    #   delivery method → configured integration → message (with {{placeholders}})
    #   → CSV path → map placeholders to columns → contact column → validate
    #   (abort or drop defects) → send → failures listed → retry failed only.
    class SendCommand
      def initialize(prompter:, credentials:)
        @prompter = prompter
        @credentials = credentials
      end

      def run
        method = pick_delivery_method
        integration_class = pick_integration(method) or return 1
        message, subject = collect_message(method)
        source = load_csv or return 1
        mapping = map_placeholders(message, source)
        contact_column = pick_contact_column(method, source)
        outcome = validate_recipients(source, contact_column, method) or return 1

        send_and_report(integration_class, outcome, message, subject, mapping)
      end

      private

      def pick_delivery_method
        @prompter.choose("Delivery method:", %w[email sms]).to_sym
      end

      def pick_integration(method)
        integrations = Registry.configured_by_method(method, @credentials)
        if integrations.empty?
          @prompter.say("No #{method} integrations are configured.")
          @prompter.say("Run `messengerr credentials setup <name>` first.")
          return nil
        end

        return integrations.first if integrations.length == 1

        keys = integrations.map(&:integration_key)
        chosen = @prompter.choose("Which #{method} integration?", keys)
        integrations[keys.index(chosen)]
      end

      def collect_message(method)
        message = @prompter.ask("Message (use {{column}} placeholders):")
        subject = @prompter.ask("Subject:") if method == :email
        [message, subject]
      end

      def load_csv
        path = @prompter.ask("Path to CSV file:")
        source = CsvSource.from(path)
        @prompter.say("Columns: #{source.headers.join(', ')}")
        source
      rescue Error => e
        @prompter.say(e.message)
        nil
      end

      def map_placeholders(message, source)
        Placeholder.extract(message).to_h do |placeholder|
          column = @prompter.choose("Map {{#{placeholder}}} to column:", source.headers)
          [placeholder, column]
        end
      end

      def pick_contact_column(method, source)
        label = { email: "email address", sms: "phone number" }[method]
        @prompter.choose("Which column holds the #{label}?", source.headers)
      end

      def validate_recipients(source, contact_column, method)
        outcome = ContactValidator.validate(source.rows, contact_column, method)

        if outcome[:defects].any?
          @prompter.say("#{outcome[:defects].length} contact(s) have defects:")
          outcome[:defects].each do |defect|
            @prompter.say("  row #{defect.row_number}: #{defect.value.inspect} — #{defect.reason}")
          end
          unless @prompter.confirm("Drop these contacts and continue? (n = abort to fix)")
            @prompter.say("Aborted. Fix the CSV and try again.")
            return nil
          end
        end

        if outcome[:valid].empty?
          @prompter.say("No valid contacts to send to — aborting.")
          return nil
        end

        outcome
      end

      def send_and_report(integration_class, outcome, message, subject, mapping)
        integration = integration_class.new(@credentials.read(integration_class.integration_key))
        options = integration_class.options_class.new
        options.subject = subject if options.respond_to?(:subject=)
        sender = Sender.new(integration, options:)

        results = sender.send(outcome[:valid], message, mapping)

        loop do
          failures = results.reject(&:sent?)
          break if failures.empty?

          @prompter.say("#{failures.length} send(s) failed:")
          failures.each do |result|
            @prompter.say("  row #{result.recipient.row_number} (#{result.recipient.contact}): #{result.reason}")
          end
          break unless @prompter.confirm("Retry failed sends?")

          retried = sender.send(failures.map(&:recipient), message, mapping)
          results = results.select(&:sent?) + retried
        end

        report = Report.new(results:, dropped: outcome[:defects])
        @prompter.say("Done — #{report.summary}")
        report.ok? ? 0 : 1
      end
    end
  end
end
