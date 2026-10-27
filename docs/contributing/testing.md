---
title: Testing
parent: Contributing
nav_order: 3
description: "How messengerr is tested: the helpers, the rules that keep specs away from the network and your real config, and how to confirm a spec tests the fix."
---

# Testing
{: .no_toc }

```sh
bundle exec rspec
bundle exec rubocop
bundle exec rake docs:check
```

CI runs all three on Ruby 3.2, 3.3 and 3.4.

## The rules

- **No real network.** `spec_helper.rb` loads WebMock, so an unstubbed request fails the spec. Stub the provider endpoints.
- **Never touch real configuration.** Build credentials with `Messengerr::Credentials.new(credentials_path:, key_path:)` pointing into a `Dir.mktmpdir`. A bare `Credentials.new` would read `~/.config/messengerr`.
- **No stray files.** Pass `--ledger` a temp path in CLI specs so nothing is written to the working directory.
- **Environment variables** go through `with_env` (`spec/support/env_helper.rb`), which restores them afterwards.
- Specs run in random order, with partial doubles verified and monkey patching disabled.

## Helpers

- `Integrations::Fake` (`spec/support/fake_integration.rb`): an email integration that fails rows whose `fail` column is `yes`. Use it for wizard, sender and ledger flows.
- `fixtures/contacts.csv`: a small list with deliberately bad rows.
- For the wizard, build a `Prompter` over `StringIO` input and output, as `send_command_spec.rb` does. Answers are positional, so keep each script readable and commented.

## What to cover

- **Provider code:** every uncertain and definite failure, with stubbed responses. These decide whether users are warned before a retry.
- **Flows:** declining the confirmation sends nothing, `--dry-run` sends nothing and writes no ledger, `--resume` skips exactly the right rows, Ctrl-C leaves an honest ledger.
- **Anything crossing layers** (CLI plus a real integration) gets an end-to-end spec. A unit spec on one class once passed while every email send was broken.

## Prove the spec tests the fix

After a spec passes, temporarily revert the fix (or change the behaviour it guards) and confirm the spec fails. Then restore it. A spec that stays green against the bug is not testing it. This is done by hand today; there is no mutation-testing tool in the project.

## Docs check

`bundle exec rake docs:check` fails if `docs/integrations.md` no longer matches the integration registry. Fix it with `bundle exec rake docs:integrations` and commit.
