# Style Guide

The conventions this codebase actually follows, not aspirational ones. Where the code is inconsistent, the last section says so and says what new code should do. Before writing something new, copy the shape of the closest existing file.

## Files and Ruby

- Ruby 3.2 or newer (`required_ruby_version` in the gemspec). `Data.define` needs it.
- Files are autoloaded by Zeitwerk: the path maps to the constant (`lib/messengerr/cli/send_command.rb` is `Messengerr::CLI::SendCommand`). The two odd names are inflections in `lib/messengerr.rb`: `cli` is `CLI` and `clicksend` is `ClickSend`. Add an inflection there rather than naming a file to fit. `version.rb` and `errors.rb` are `require_relative`d and ignored by the loader.
- No `# frozen_string_literal` magic comment (no file in `lib/` or `spec/` uses one). Don't add it to a single file.
- Double-quoted strings. Single quotes appear only inside `#{...}` interpolation.
- Two-space indentation, no semicolons. Array literals have spaces inside the brackets (`[ :from ]`); that is the omakase RuboCop style, and `rubocop -a` fixes it. Endless methods (`def sent? = status == :sent`) are for one-line predicates and readers only.
- Use keyword shorthand where the variable has the field's name: `Result.new(recipient:, status: :failed)`.
- A short comment above a class or method says what it is *for* or the non-obvious rule it enforces. Return shapes are noted as `# → [Result], one per delivery`. Don't comment what the code already says.
- Style is enforced by RuboCop (`rubocop-rails-omakase`): `bundle exec rubocop`.

## Value objects

Immutable records are `Data.define`: `Recipient`, `Delivery`, `Result`, `ContactValidator::Defect`. Add defaults by overriding `initialize` with keyword arguments and calling `super` (see `Result`). Don't mutate; build a new one.

## Integrations

An integration is three classes with the **same name** in parallel namespaces: `Integrations::X`, `Setups::X`, `SendingOptions::X`. The class name, lowercased, is the key users type. `Base.setup_class` and `Base.options_class` resolve them with `const_get(name, false)`; override the class methods only to wire something explicitly.

The contract (also in `docs/writing-an-integration.md`):

- `Integrations::Base.formats` lists the body formats the integration can send; the default is `[ :text ]`. Declare `:html` only if you send `delivery.body` as the provider's HTML field when `delivery.html?`, one body per message, never both.
- `send_batch(deliveries, options)` returns exactly one `Result` per delivery. It may `yield` each result as it lands so the ledger stays exact if a run dies mid-batch.
- Mark a failure `uncertain: true` unless the provider **definitely rejected** it. A timeout after sending, a dropped connection, a 5xx or an unreadable response is uncertain. Raise `IntegrationError` for a definite failure and `UncertainError` for an uncertain one.
- `verify!` is a cheap live call and raises `IntegrationError` with no secret in the message.
- Set explicit network timeouts. Use the standard library (`Net::HTTP`) unless an official client is a clear win (Postmark).
- New sending options need an entry in `DocsIntegrations::DESCRIPTIONS` (`rakelib/docs_integrations.rb`) or `rake docs:check` fails.

## Errors

- Everything we raise inherits `Messengerr::Error` (`CredentialsError`, `IntegrationError`, `UncertainError`, `ValidationError`, `RenderError`). `CLI#start` rescues `Error` once and prints `messengerr: <message>`; the exit code is 1.
- Don't let a raw `Errno`, `Open3`, `JSON::ParserError` or `OptionParser` exception reach the user. Translate it at the boundary where it happens (see `CsvSource.from`, `Ledger#verify_writable!`, `SendCommand#parse_flags`).
- A message says what happened and, when there is a fix, what to do: ``run `messengerr credentials setup postmark` ``.
- **Never put a secret in an error message, a log line, a command-line argument or the ledger.** Don't echo a rejected `MESSENGERR_MASTER_KEY` value.
- User-facing text uses an em dash (`—`) as the separator, as in `Aborted — nothing was sent.`

## CLI

- Commands are plain classes constructed with `prompter:` and `credentials:`. All interaction goes through the injected `Prompter`; only `CLI#start` writes to its `out`.
- `run` returns an Integer exit code (0, 1, or 130 for Ctrl-C). Only `exe/messengerr` calls `exit`.
- Flags are parsed with `OptionParser` inside the command. A bad flag is a `Messengerr::Error`, raised before any prompt.

## Invariants (do not break these)

These are the product's promises. A change that weakens one needs a deliberate decision, a spec, and a docs update.

- **Nothing is sent before the user has seen a preview and confirmed.** `--dry-run` never sends or writes a ledger.
- **Never send unrendered text.** Any leftover `{{` or `}}` aborts the run.
- **Templates are logic-free.** A `{{name}}` substitutes one mapped CSV column and nothing else: no conditionals, loops, filters or expressions. Anything that is not a plain placeholder is left in place and aborts the run (`unrenderable placeholder left in message`). Adding logic needs a deliberate decision, a way to preview every variation, and a docs update.
- **A real send needs an interactive terminal.** Without `--dry-run`, `SendCommand` refuses (before reading anything) unless `Prompter#interactive?` is true or `--allow-non-interactive` is given. Do not add another way around it. Specs model a person with `Prompter.new(interactive: true)`; the end-to-end behaviour is covered by `spec/messengerr/exe_spec.rb`, which also runs under a pseudo-terminal so the guard can never block a human.
- **Flags only pre-answer prompts.** A flag is validated exactly like the prompt it replaces (blank values, unknown columns and integrations are errors), and a flag never skips the preview or the confirmation.
- **One row is one message.** Contacts are not de-duplicated.
- **CSV values are HTML-escaped in HTML mode, and HTML only reaches integrations that declare it.** `Renderer.render(..., escape: true)` for `--html`; the subject is never escaped; the CLI refuses `--html` for SMS and for integrations without `:html` in `formats`.
- **One `Result` per `Delivery`.** `Sender` fills any gap with a failed, uncertain result.
- **Record as results land.** The ledger is appended per result, not at the end, and the ledger must be writable before the first send. If it stops being writable, stop sending.
- **Uncertain unless definitely rejected.** This drives the duplicate warning before a retry or `--resume`.
- **`--resume` identifies a recipient by `[row_number, contact]`**, never by contact alone.
- **Secrets at rest:** credentials and ledger files are `0600`, their directories `0700`, written to a temp file and renamed. A directory that already exists is never chmod-ed.
- **No new runtime dependency** without a reason in the PR. Today: `base64`, `csv`, `phonelib`, `postmark`, `zeitwerk`.

## Specs

- `spec/` mirrors `lib/`: `spec/messengerr/ledger_spec.rb` tests `Messengerr::Ledger`. Use `RSpec.describe ClassName`. `spec_helper.rb` turns on random order, `verify_partial_doubles` and `disable_monkey_patching!`.
- **No real network.** WebMock is loaded for every spec. Stub the provider endpoints.
- **Never touch real configuration.** Build credentials with `Messengerr::Credentials.new(credentials_path:, key_path:)` pointing into a `Dir.mktmpdir`. A bare `Credentials.new` reads `~/.config/messengerr`. Pass `--ledger` a temp path so specs don't write into the working directory.
- Set environment variables with the `with_env` helper (`spec/support/env_helper.rb`), which restores them.
- Flow specs use the `Fake` integration (`spec/support/fake_integration.rb`). Provider specs use the real classes with stubbed HTTP. Anything that crosses the CLI and a real integration (for example email through Postmark) gets an end-to-end spec: a unit spec on the options class alone once let a send-breaking bug through.
- Fixing a bug starts with a failing spec. Then check the spec by hand: revert the fix and confirm the spec fails.
- Assert behaviour (what was sent, what was recorded, what the user saw), not the internals.

## Docs

- `docs/` is a Jekyll site (just-the-docs). `docs/integrations.md` is generated: run `bundle exec rake docs:integrations` and commit the result. CI runs `rake docs:check`.
- Document only what you ran. Every command, flag, exit code and message in the docs should match the code.
- User-visible changes get a `CHANGELOG.md` entry.

## Where the code is not consistent yet

New code should follow the recommendation.

- **Class comments.** Roughly half the classes have an opening comment. Add one when the name doesn't explain the purpose.
- **`class << self` vs `def self.`** Both appear (`Registry` and `SendingOptions::Base` use the first, most others the second). Prefer `def self.` for a few methods, and `class << self` when you also need private class helpers.
- **Hand-rolled prompts.** `Setups::Base` prompts every required key as a hidden secret, including non-secret values such as `from`. A secret/non-secret distinction is wanted, not built.
- **Rescue breadth.** A few `rescue StandardError` blocks exist at integration boundaries on purpose (a failed send must become a `Result`, not a crash). Elsewhere, rescue the narrowest class you can.
