---
title: Writing an integration
nav_order: 10
description: "How to add a delivery provider to messengerr: the three classes, the result contract, uncertain failures, and how to load your integration today."
---

# Writing an integration
{: .no_toc }

An integration connects messengerr to a delivery provider. It is three small classes in parallel namespaces. This page covers the contract. For the checklist to add a **built-in** integration to this repository, see [Contributing]({{ '/contributing/writing-an-integration.html' | relative_url }}).

<details open markdown="block">
  <summary>On this page</summary>
  {: .text-delta }
1. TOC
{:toc}
</details>

## The three classes

The classes share a name and live in `Messengerr::Integrations`, `Messengerr::Setups` and `Messengerr::SendingOptions`. The integration's key (what users type in `credentials setup NAME`) is the class name, lowercased: `Acme` becomes `acme`.

```ruby
require "messengerr"

module Messengerr
  module Integrations
    class Acme < Base
      def self.delivery_method = :sms # :email or :sms

      # Cheap live call proving the credentials work.
      # Raise IntegrationError (without the secret in the message) on failure.
      def verify!
        raise IntegrationError, "Acme rejected the credentials" unless ping_ok?(@credentials["api_key"])

        true
      end

      # deliveries: [Messengerr::Delivery(recipient:, body:, subject:)]
      # Return exactly one Result per delivery, in any order.
      def send_batch(deliveries, options)
        deliveries.map do |delivery|
          result = send_one(delivery, options)
          yield result if block_given? # record it now, in case a later send crashes
          result
        end
      end
    end
  end

  module Setups
    class Acme < Base
      def self.required_keys = [ :api_key ]
      def self.optional_keys = [ :region ]
    end
  end

  module SendingOptions
    class Acme < Base
      option :priority

      def validate!
        super
        raise ValidationError, "priority must be 1-3" unless priority.nil? || (1..3).cover?(priority)

        true
      end
    end
  end
end
```

`@credentials` is a hash with **string** keys, holding whatever the setup collected. `Setups::Base` handles prompting, hidden input, live verification and encrypted storage for you from `required_keys` and `optional_keys`.

`SendingOptions::Base` already provides `from`, `batch_size` (default 50), `rate_limit` (default 10) and `metadata`. Add your own with `option :name`.

## The data you receive

| Object | Fields |
|---|---|
| `Delivery` | `recipient`, `body` (fully rendered), `subject` (rendered, or `nil` for SMS), `format` (`:text` or `:html`) |
| `Recipient` | `contact` (normalised address or E.164 number), `row` (the CSV row hash), `row_number` |

## The result contract

Build results with `Messengerr::Result.new(recipient:, status:, reason:, provider_id:, uncertain:)`.

- `status` is `:sent` or `:failed`. `sent` means the provider **accepted** the message, not that it was delivered.
- `provider_id` is the provider's message ID, if it gives one.
- `reason` explains a failure. It is shown on screen and stored in the ledger, so **never put secrets in it**.
- **`uncertain: true`** on a failure whenever the provider might have accepted the message anyway: a timeout after sending, a dropped connection, a 5xx, a response you cannot read. Mark a failure definite (`uncertain: false`, the default) only when the provider clearly rejected it. This drives the duplicate warning before a retry. See [Ledger and resume]({{ '/ledger-and-resume.html' | relative_url }}).

Rules messengerr enforces for you:

- If you return fewer results than deliveries, each missing recipient becomes a failed, uncertain result (`integration returned no result`).
- If `send_batch` raises, the whole batch fails. A plain `Messengerr::IntegrationError` means a definite failure. `Messengerr::UncertainError` (a subclass) and any other exception mean uncertain. Results you already `yield`ed are kept.
- If the user presses Ctrl-C, everything you did not yield is recorded as uncertain.

Yielding each result as soon as you have it is optional, but worth doing if your provider has no true batch call: it keeps the [ledger]({{ '/ledger-and-resume.html' | relative_url }}) exact if a run dies half-way through a batch.

Set explicit network timeouts. A call that can hang forever stalls the whole run.

## HTML bodies

By default messengerr only hands your integration plain text. To receive HTML, declare it:

```ruby
def self.formats = [ :text, :html ]
```

Then check `delivery.html?` (or `delivery.format`) when you build the request and send `delivery.body` as the provider's HTML field. HTML is **HTML only**: there is no plain-text twin. `messengerr send --html` is refused for any integration that does not list `:html`, so markup can never be sent as plain text by accident. The CSV values in an HTML `body` are already HTML-escaped.

## Loading your integration

messengerr does not discover plugin gems automatically yet. Until it does, load your file before the CLI starts, for example with `RUBYOPT`:

```sh
RUBYOPT="-r/path/to/acme.rb" messengerr integrations
RUBYOPT="-r/path/to/acme.rb" messengerr credentials setup acme
RUBYOPT="-r/path/to/acme.rb" messengerr send
```

Your file should `require "messengerr"` itself, as in the example above. Defining a named subclass of `Messengerr::Integrations::Base` registers it automatically. Two integrations cannot share a key: the second raises `integration key :acme is already taken by ...`.

{: .warning }
An integration receives its own credentials and, for every send, each recipient's contact details and the rendered message. Only load integration code you trust.

## Current limits

- The wizard and the contact validators understand two delivery methods, `:email` and `:sms`. A new kind of channel (push, chat) needs changes inside messengerr itself, not just a plugin.
- Messages are plain text unless your integration declares HTML support (below).
- Sending options beyond `from`, `batch_size` and `rate_limit` are not reachable from the command line yet.
