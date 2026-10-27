require "optparse"
require "set"

module Messengerr
  class CLI
    # messengerr send [flags] — interactive wizard:
    #   delivery method → configured integration → message (with {{placeholders}})
    #   → CSV path → map placeholders to columns → contact column → validate
    #   (abort or drop defects) → preview → confirm → send → failures listed
    #   → retry failed only.
    #
    # Flags: --dry-run, --resume LEDGER, --ledger PATH, --batch-size N,
    #        --rate-limit N, --from ADDRESS, --message-file FILE, --html FILE
    class SendCommand
      SMS_SEGMENT = 160
      # Sending options settable from flags (the integrations support more; see docs/integrations.md).
      CLI_OPTIONS = %i[from batch_size rate_limit].freeze

      def initialize(prompter:, credentials:)
        @prompter = prompter
        @credentials = credentials
        @flags = { ledger: Ledger.default_path }
      end

      def run(args = [])
        parse_flags(args)
        if @flags[:help]
          @prompter.say(@parser.help)
          return 0
        end
        guard_interactive!
        check_resume_ledger!
        @file_message = load_message_file

        method = pick_delivery_method
        check_html_method!(method)
        check_subject_method!(method)
        integration_class = pick_integration(method) or return 1
        check_html_supported!(integration_class)
        message, subject = collect_message(method)
        source = load_csv or return 1
        mapping = map_placeholders(message, subject, source) or return 1
        contact_column = pick_contact_column(method, source) or return 1
        outcome = validate_recipients(source, contact_column, method) or return 1
        deliveries = preview_and_confirm(outcome[:valid], message, subject, mapping, method) or return 1

        send_and_report(integration_class, deliveries, outcome[:defects])
      end

      private

      # Bad flags are user errors, not crashes: they surface as Messengerr::Error
      # (printed as "messengerr: ..." with exit 1) before any prompt appears.
      def parse_flags(args)
        @parser = build_parser
        extra = @parser.parse(args)
        raise Error, "unexpected argument: #{extra.join(' ')} (see `messengerr send --help`)" unless extra.empty?
        raise Error, "use either --html or --message-file, not both (see `messengerr send --help`)" if @flags[:html] && @flags[:message_file]
        raise Error, "use either --message or --message-file/--html, not both" if @flags[:message] && (@flags[:message_file] || @flags[:html])
      rescue OptionParser::ParseError => e
        raise Error, "#{e.message} (see `messengerr send --help`)"
      end

      def build_parser
        OptionParser.new do |opts|
          opts.banner = "Usage: messengerr send [flags]"
          opts.on("--method METHOD", %w[email sms], "Delivery method (skips the chooser)") { |v| @flags[:method] = v.to_sym }
          opts.on("--integration NAME", "Integration to use (e.g. postmark, clicksend)") { |v| @flags[:integration] = present("--integration", v) }
          opts.on("--dry-run", "Preview the rendered messages; send nothing") { @flags[:dry_run] = true }
          opts.on("--csv PATH", "Contact CSV (skips the path prompt)") { |v| @flags[:csv] = present("--csv", v) }
          opts.on("--contact COLUMN", "Column holding the email/phone contact value") { |v| @flags[:contact] = present("--contact", v) }
          opts.on("--map PLACEHOLDER=COLUMN", "Map a {{placeholder}} to a CSV column (repeatable)") do |v|
            key, column = v.split("=", 2)
            raise OptionParser::InvalidArgument, "#{v} (expected PLACEHOLDER=COLUMN)" if key.nil? || column.nil? || key.empty? || column.empty?
            (@flags[:map] ||= {})[key] = column
          end
          opts.on("--message TEXT", "Message body as a literal argument") { |v| @flags[:message] = present("--message", v) }
          opts.on("--subject TEXT", "Email subject line ({{placeholders}} allowed)") { |v| @flags[:subject] = present("--subject", v) }
          opts.on("--allow-non-interactive", "Send without an interactive terminal (human scripts only)") { @flags[:allow_non_interactive] = true }
          opts.on("--resume LEDGER", "Skip recipients already sent in this ledger (row + contact)") do |v|
            @flags[:resume] = v
            @flags[:ledger] = v
          end
          opts.on("--ledger PATH", "Where to record results (default: ./messengerr-ledger-<time>.jsonl)") { |v| @flags[:ledger] = v }
          opts.on("--batch-size N", Integer, "Messages per batch") { |v| @flags[:batch_size] = positive(v) }
          opts.on("--rate-limit N", Integer, "Batches per second") { |v| @flags[:rate_limit] = positive(v) }
          opts.on("--from ADDRESS", "Override the sender address/ID") { |v| @flags[:from] = v }
          opts.on("--message-file FILE", "Read a multi-line plain-text message from FILE instead of typing one line") { |v| @flags[:message_file] = v }
          opts.on("--html FILE", "Send FILE as an HTML email (email only; HTML only, no text version)") { |v| @flags[:html] = v }
          opts.on("-h", "--help", "Show this help") { @flags[:help] = true }
        end
      end

      # A blank value is almost always a mistake (an empty shell variable), and
      # for --message it would mean sending an empty message.
      def present(flag, value)
        raise Error, "#{flag} can't be blank (see `messengerr send --help`)" if value.strip.empty?

        value
      end

      def positive(value)
        raise OptionParser::InvalidArgument, "#{value} (must be a positive integer)" unless value.positive?

        value
      end

      # Real sends are for humans at terminals. An agent shell or CI hitting
      # this path gets a clear refusal; the documented escape hatch exists for
      # the user's own scripts only.
      def guard_interactive!
        return if @flags[:dry_run] || @flags[:allow_non_interactive] || @prompter.interactive?

        raise Error, "refusing to send without an interactive terminal: run `messengerr send` yourself in a terminal " \
                     "(or pass --allow-non-interactive in your own scripts). --dry-run works anywhere."
      end

      # A mistyped --resume path must not silently mean "nothing sent yet".
      def check_resume_ledger!
        return unless @flags[:resume]
        return if File.file?(@flags[:resume])

        raise Error, "resume ledger not found: #{@flags[:resume]}"
      end

      # The message from --html / --message-file, normalised, or nil when the
      # message will be typed. Problems surface before any prompt.
      def load_message_file
        path = @flags[:html] || @flags[:message_file]
        return nil unless path

        expanded = File.expand_path(path)
        raise Error, "message file not found: #{path}" unless File.file?(expanded)

        text = File.read(expanded, encoding: "bom|utf-8")
        raise Error, "message file is not valid UTF-8: #{path}" unless text.valid_encoding?

        text = text.gsub("\r\n", "\n").rstrip
        raise Error, "message file is empty: #{path}" if text.empty?

        text
      rescue SystemCallError => e
        raise Error, "cannot read message file #{path}: #{e.message}"
      end

      def check_html_method!(method)
        raise Error, "--html is only for email; SMS messages are plain text (use --message-file)" if @flags[:html] && method != :email
      end

      def check_subject_method!(method)
        raise Error, "--subject is only for email; SMS messages have no subject" if @flags[:subject] && method != :email
      end

      def check_html_supported!(integration_class)
        return unless @flags[:html]
        return if integration_class.formats.include?(:html)

        raise Error, "#{integration_class.integration_key} can't send HTML email"
      end

      def message_format = @flags[:html] ? :html : :text

      def pick_delivery_method
        @flags[:method] || @prompter.choose("Delivery method:", %w[email sms]).to_sym
      end

      def pick_integration(method)
        integrations = Registry.configured_by_method(method, @credentials)
        if integrations.empty?
          @prompter.say("No #{method} integrations are configured.")
          @prompter.say("Run `messengerr credentials setup <name>` first.")
          return nil
        end

        if @flags[:integration]
          wanted = @flags[:integration].to_sym
          match = integrations.find { |i| i.integration_key == wanted }
          unless match
            @prompter.say("Integration '#{wanted}' is not configured for #{method}. " \
                          "Configured: #{integrations.map(&:integration_key).join(', ')}")
            return nil
          end
          return match
        end

        return integrations.first if integrations.length == 1

        keys = integrations.map(&:integration_key)
        chosen = @prompter.choose("Which #{method} integration?", keys)
        integrations[keys.index(chosen)]
      end

      def collect_message(method)
        message = @file_message || @flags[:message]
        if @file_message
          @prompter.say("Message: #{message.lines.length} line(s) from #{@flags[:html] || @flags[:message_file]}")
        elsif message.nil?
          message = @prompter.ask("Message (use {{column}} placeholders):")
        end
        subject = @flags[:subject] || (ask_subject if method == :email)
        [ message, subject ]
      end

      # Email needs a subject; re-ask now rather than failing after the wizard.
      def ask_subject
        loop do
          subject = @prompter.ask("Subject ({{placeholders}} allowed):")
          return subject unless subject.strip.empty?

          @prompter.say("A subject is required for email.")
        end
      end

      def load_csv
        path = @flags[:csv] || @prompter.ask("Path to CSV file:")
        source = CsvSource.from(path)
        @prompter.say("Columns: #{source.headers.join(', ')}")
        source
      rescue Error => e
        @prompter.say(e.message)
        nil
      end

      # Placeholders in the subject are mapped just like body placeholders.
      def map_placeholders(message, subject, source)
        placeholders = Placeholder.extract(message) + Placeholder.extract(subject)
        flag_map = @flags[:map] || {}
        flag_map.each_key do |placeholder|
          unless source.headers.include?(flag_map[placeholder])
            @prompter.say("--map #{placeholder}=#{flag_map[placeholder]}: no such column in the CSV.")
            return nil
          end
        end
        unused = flag_map.keys - placeholders
        unless unused.empty?
          @prompter.say("Note: --map #{unused.join(', ')} not used: no such {{placeholder}} in the message or subject.")
        end
        placeholders.uniq.to_h do |placeholder|
          column = flag_map[placeholder] || @prompter.choose("Map {{#{placeholder}}} to column:", source.headers)
          [ placeholder, column ]
        end
      end

      def pick_contact_column(method, source)
        label = { email: "email address", sms: "phone number" }[method]
        column = @flags[:contact] || @prompter.choose("Which column holds the #{label}?", source.headers)
        unless source.headers.include?(column)
          @prompter.say("--contact #{column}: no such column in the CSV.")
          return nil
        end
        column
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

      # H1 guardrail: show what will actually go out before anything is sent.
      def preview_and_confirm(recipients, message, subject, mapping, method)
        deliveries = recipients.map do |recipient|
          Delivery.new(
            recipient:,
            body: Renderer.render(message, recipient.row, mapping, escape: message_format == :html),
            subject: subject && Renderer.render(subject, recipient.row, mapping),
            format: message_format
          )
        rescue RenderError => e
          @prompter.say("row #{recipient.row_number}: #{e.message}")
          @prompter.say("Aborted — fix the CSV or mapping and try again.")
          return nil
        end

        deliveries = resume_filter(deliveries) or return nil

        @prompter.say("--- Preview (#{deliveries.length} message#{'s' if deliveries.length != 1}) ---")
        deliveries.first(3).each do |d|
          @prompter.say("To: #{d.recipient.contact}")
          @prompter.say("Subject: #{d.subject}") if d.subject
          say_body(d)
          @prompter.say("   (#{sms_segments(d.body)} SMS segment(s))") if method == :sms
          @prompter.say("...")
        end
        write_html_preview(deliveries.first) if message_format == :html

        return deliveries if @flags[:dry_run] || @prompter.confirm("Send #{deliveries.length} message(s)?")

        @prompter.say("Aborted — nothing was sent.")
        nil
      end

      # Multi-line text is indented under "Body:"; HTML is never dumped to the terminal.
      def say_body(delivery)
        if delivery.html?
          @prompter.say("Body: HTML, #{delivery.body.length} characters")
        elsif delivery.body.include?("\n")
          @prompter.say("Body:")
          delivery.body.each_line { |line| @prompter.say("  #{line.chomp}") }
        else
          @prompter.say("Body: #{delivery.body}")
        end
      end

      # Lets the user open the first rendered message in a browser before confirming.
      def write_html_preview(delivery)
        path = File.join(Dir.pwd, "messengerr-preview.html")
        File.write(path, delivery.body, mode: "w", perm: 0o600)
        @prompter.say("HTML preview of the first message: #{path}")
      rescue SystemCallError => e
        @prompter.say("(could not write the HTML preview: #{e.message})")
      end

      def resume_filter(deliveries)
        return deliveries unless @flags[:resume]

        warn_uncertain(deliveries)
        sent = Ledger.sent_recipients(@flags[:resume]).to_set
        skipped = deliveries.count { |d| sent.include?(recipient_key(d)) }
        remaining = deliveries.reject { |d| sent.include?(recipient_key(d)) }
        @prompter.say("Resuming: #{skipped} already sent, #{remaining.length} remaining.")
        if remaining.empty?
          @prompter.say("Nothing left to send.")
          return nil
        end
        remaining
      end

      # How the ledger identifies a recipient: row + contact, so repeated
      # contacts are tracked per row.
      def recipient_key(delivery)
        [ delivery.recipient.row_number, delivery.recipient.contact ]
      end

      # Earlier attempts that timed out etc. may have been delivered; --resume
      # will send to them again, so say so before the confirmation.
      def warn_uncertain(deliveries)
        uncertain = Ledger.uncertain_recipients(@flags[:resume]).to_set
        at_risk = deliveries.map { |d| recipient_key(d) }.select { |key| uncertain.include?(key) }.map(&:last)
        return if at_risk.empty?

        @prompter.say("Warning: #{at_risk.length} contact(s) had an earlier attempt with an unknown outcome " \
                      "and will be sent again — they may receive duplicates:")
        at_risk.first(10).each { |contact| @prompter.say("  #{contact}") }
        @prompter.say("  ...and #{at_risk.length - 10} more") if at_risk.length > 10
      end

      def send_and_report(integration_class, deliveries, defects)
        integration = integration_class.new(@credentials.read(integration_class.integration_key))
        options = build_options(integration_class)
        ledger = Ledger.new(@flags[:ledger])
        sender = Sender.new(integration, options:, ledger:)

        if @flags[:dry_run]
          @prompter.say("Dry run — nothing sent. Ledger skipped.")
          return 0
        end

        ledger.verify_writable!
        results = deliver_all(sender, deliveries) or return 130

        loop do
          failures = results.reject(&:sent?)
          break if failures.empty?

          list_failures(failures)
          break if sender.halted_reason
          break unless retry_confirmed?(failures)

          retrying = deliveries.select { |d| failures.any? { |f| f.recipient == d.recipient } }
          retried = deliver_all(sender, retrying) or return 130
          results = results.select(&:sent?) + retried
        end

        @prompter.say("Stopped early: #{sender.halted_reason}") if sender.halted_reason
        @prompter.say("Ledger written to #{@flags[:ledger]}")
        report = Report.new(results:, dropped: defects)
        @prompter.say("Done — #{report.summary}")
        report.ok? ? 0 : 1
      end

      # → [Result], or nil if the user hit Ctrl-C (the ledger already holds
      # everything that was delivered; unreported sends are marked uncertain).
      def deliver_all(sender, deliveries)
        sender.deliver(deliveries)
      rescue Interrupt
        @prompter.say("\nInterrupted. Ledger: #{@flags[:ledger]}")
        @prompter.say("Resume later with: messengerr send --resume #{@flags[:ledger]}")
        nil
      end

      def list_failures(failures)
        @prompter.say("#{failures.length} send(s) failed:")
        failures.each do |result|
          line = "  row #{result.recipient.row_number} (#{result.recipient.contact}): #{result.reason}"
          line += " [uncertain — may already be delivered]" if result.uncertain
          @prompter.say(line)
        end
      end

      def retry_confirmed?(failures)
        if failures.any?(&:uncertain)
          @prompter.say("Warning: some failures are uncertain — retrying may send duplicates.")
        end
        @prompter.confirm("Retry failed sends?")
      end

      def build_options(integration_class)
        options = integration_class.options_class.new
        CLI_OPTIONS.each do |key|
          options.public_send("#{key}=", @flags[key]) if @flags[key] && options.respond_to?("#{key}=")
        end
        options
      end

      def sms_segments(body)
        body.length <= SMS_SEGMENT ? 1 : (body.length / 153.0).ceil
      end
    end
  end
end
