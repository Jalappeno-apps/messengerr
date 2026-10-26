# Messengerr

Send templated messages to a CSV contact list over email and SMS — interactively, from your terminal.

Write a message with `{{placeholders}}`, point it at a CSV, map each placeholder to a column, and messengerr validates the contacts, shows you any defects, sends through your configured integration, and offers retries for failures.

## Install

```sh
gem install messengerr
```

## How it works

| Piece | What it is |
|---|---|
| **Integrations** | Providers that deliver your messages. Scoped by delivery method (`email`, `sms`). Built-ins: **Postmark** (email), **ClickSend** (SMS). |
| **Credentials** | Integration API keys, stored in a Rails-credentials-style AES-256-GCM encrypted YAML file with a per-install master key — both inside the installed gem directory, so they're removed when the gem is uninstalled. |
| **Sending options** | Per-integration option classes (`from`, `batch_size`, `rate_limit`, plus integration-specific like Postmark's `tag`/`message_stream`). |

## Credentials

```sh
messengerr credentials setup postmark    # interactive: prompts keys, verifies live, stores encrypted
messengerr credentials list              # what's registered and configured
messengerr credentials verify postmark   # re-check stored credentials against the API
messengerr credentials delete            # remove the encrypted file
messengerr credentials delete --purge    # also remove the master key
messengerr integrations                  # list integrations by delivery method
```

The encrypted file lives at `<gem>/config/credentials.yml.enc`, the master key at `<gem>/config/master.key` (both `chmod 600`). If the gem is installed to a read-only location, you'll get a clear error. If the master key is lost, the file can't be decrypted — run `credentials delete` to reset.

## Sending

```sh
messengerr send
```

The wizard walks you through:

1. **Delivery method** — `email` or `sms`
2. **Integration** — configured integrations for that method
3. **Message** — use `{{column_name}}` placeholders (`Hi {{first_name}}, your code is {{code}}`); email also asks for a subject
4. **CSV path** — local file; columns are shown
5. **Placeholder mapping** — map each `{{placeholder}}` to a CSV column
6. **Contact column** — which column holds the email address / phone number
7. **Validation** — emails checked by regex, phones normalized to E.164 via `phonelib`. Defects are listed by row; choose to **drop them** or **abort** to fix the CSV
8. **Send** — batched with rate limiting; per-recipient failures are collected, never abort the run
9. **Failures** — listed with reasons; retry **failed sends only**

### Phone numbers

Set a default country for local-format numbers:

```sh
export MESSENGERR_DEFAULT_COUNTRY=US
```

## Writing a community integration

Package three small classes (recommended gem name `messengerr-<name>`):

```ruby
# the delivery contract
class Acme < Messengerr::Integrations::Base
  def self.delivery_method = :sms

  def initialize(credentials) = @credentials = credentials

  def verify!
    # cheap live API check; raise Messengerr::IntegrationError on failure
  end

  def send_batch(pairs, options)
    # pairs = [[recipient, rendered_message], ...]
    # → [Messengerr::Result.new(recipient:, status: :sent|:failed, reason:, provider_id:)]
  end
end

# the interactive setup
class Acme < Messengerr::Setups::Base
  def self.required_keys = [:api_key]
  def self.optional_keys = [:region]
end

# the options (optional — base provides from/batch_size/rate_limit/metadata)
class Acme < Messengerr::SendingOptions::Base
  option :schedule
end

Messengerr.register_integration(Acme)
```

Put them in the parallel namespaces `Messengerr::Integrations::<Name>`, `Messengerr::Setups::<Name>`, `Messengerr::SendingOptions::<Name>` and the CLI picks them up automatically.

## Development

```sh
bundle install
bundle exec rspec   # 100 examples, WebMock — no real API calls
```

## License

MIT
