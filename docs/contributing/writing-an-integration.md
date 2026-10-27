---
title: Writing an integration
parent: Contributing
nav_order: 2
description: "Checklist for adding a built-in provider to messengerr: classes, specs, generated docs, and what to verify."
---

# Writing an integration
{: .no_toc }

The contract itself is documented for everyone in [Writing an integration]({{ '/writing-an-integration.html' | relative_url }}). This page is the checklist for adding a **built-in** one to the repository.

## Checklist

1. **Classes.** Add `lib/messengerr/integrations/<name>.rb`, `lib/messengerr/setups/<name>.rb` and `lib/messengerr/sending_options/<name>.rb`. Same class name in each parallel namespace. If the file name does not map to the constant (like `clicksend` to `ClickSend`), add an inflection in `lib/messengerr.rb`.
2. **Formats.** Plain text is the default. If the provider can send HTML, declare `def self.formats = [ :text, :html ]` and send `delivery.body` as the HTML field when `delivery.html?`: one body per message, never both.
3. **Results.** Return one `Result` per `Delivery`. Mark failures `uncertain: true` unless the provider definitely rejected the message. Use `UncertainError` for batch-level uncertainty. `yield` each result if you send one at a time.
4. **Timeouts and errors.** Set explicit timeouts. Translate network exceptions into `IntegrationError` or `UncertainError` as described in [STYLE.md](https://github.com/jalappeno-apps/messengerr/blob/main/STYLE.md). Never put a secret in a message.
5. **Specs.** Under `spec/messengerr/integrations/`, `setups/` and `sending_options/`. Stub every HTTP call with WebMock. Cover:
   - `verify!` success and failure.
   - A sent result with its `provider_id`, and a provider rejection.
   - **Every uncertain and definite case**: 4xx, 5xx, timeouts, a dropped connection, an unreadable body, a missing per-message status.
   - That secrets never appear in `reason` strings.
6. **End to end.** Add a spec in `spec/messengerr/cli/send_command_spec.rb` that runs the real CLI with your real integration class and stubbed HTTP, as the Postmark one does.
7. **Descriptions.** Add a `DocsIntegrations::DESCRIPTIONS` entry for each new sending option in `rakelib/docs_integrations.rb`.
8. **Docs.** `bundle exec rake docs:integrations`, then commit `docs/integrations.md`. Update the Limitations page if the integration changes what is possible.
9. **Changelog.** Add a line to `CHANGELOG.md`.
10. **Verify by hand.** Revert a key behaviour (for example, treat a 5xx as definite) and confirm a spec fails.

{: .note }
The wizard and the contact validators support two delivery methods, `email` and `sms`. A provider for a new kind of channel needs changes in `SendCommand` and `ContactValidator` as well.
