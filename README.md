<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/jalappeno-apps/messengerr/main/docs/assets/images/logo-lockup-dark.svg">
    <img alt="messengerr" src="https://raw.githubusercontent.com/jalappeno-apps/messengerr/main/docs/assets/images/logo-lockup.svg" height="56">
  </picture>
</p>

<p align="center"><b>Send templated email and SMS to a CSV contact list, safely, from your terminal.</b></p>

Write one message with `{{placeholders}}`, point messengerr at a CSV, and it validates the contacts, shows you exactly what will go out, sends through your provider, and keeps a record of every result.

**Documentation: [jalappeno-apps.github.io/messengerr](https://jalappeno-apps.github.io/messengerr/)**

## Install

With [Homebrew](https://brew.sh) (macOS and Linux), which brings its own Ruby:

```sh
brew install Jalappeno-apps/messengerr/messengerr
```

Or with RubyGems, which needs Ruby 3.2 or newer:

```sh
gem install messengerr
```

## Quick start

```sh
messengerr credentials setup postmark   # or clicksend; keys are verified live, then stored encrypted
messengerr send --dry-run               # walk the wizard and preview, sending nothing
messengerr send                         # preview, confirm, send
```

Every wizard question also has a flag, so a send can be one command. Preview it anywhere with `--dry-run`, then run the same command without it in a terminal:

```sh
messengerr send --method email --csv contacts.csv --contact email --map name=name \
  --message "Hi {{name}}, your invoice is ready." --subject "Invoice for {{name}}" --dry-run
```

A real send is refused unless a person is at a terminal (so an automated shell can prepare and preview, but not send).

Given a CSV like

```text
name,email,plan
Ann,ann@example.com,Pro
Bob,bob@example.com,Team
```

and the message `Hi {{name}}, your {{plan}} invoice is ready.`, the preview shows:

```text
--- Preview (2 messages) ---
To: ann@example.com
Subject: Invoice for Ann
Body: Hi Ann, your Pro invoice is ready.
...
```

## Why it is safe to point at a real list

- **Preview first.** You see the count and the first rendered messages, then confirm. `--dry-run` sends nothing.
- **Bad data is surfaced, not sent.** Invalid contacts are listed by row. A malformed or empty placeholder aborts the run instead of going out as literal text.
- **See the real thing.** HTML emails (`--html letter.html`) are written to a preview file you can open in a browser before you confirm. Values from the CSV are HTML-escaped.
- **A record of every result.** Each outcome is appended to a ledger as it happens, so a crash or Ctrl-C never loses track of who was messaged.
- **Resume without guessing.** `--resume` skips recipients already sent. Failures that might already have been delivered are marked *uncertain* and flagged before you retry.

## Integrations

| Integration | Delivers |
|---|---|
| Postmark | email |
| ClickSend | SMS |

New providers follow a small contract. See [Writing an integration](https://jalappeno-apps.github.io/messengerr/writing-an-integration.html).

## Use it with Claude

An optional skill lets Claude Code prepare and dry-run a send for you. Claude never sends: you run the final command yourself. It needs messengerr 0.2.0 or newer.

```
/plugin marketplace add Jalappeno-apps/messengerr_skill
```

Then install the `messengerr` plugin from the catalog and start a new session. See [Using with Claude](https://jalappeno-apps.github.io/messengerr/using-with-claude.html) for the manual install and what Claude may and may not do.

## Good to know

messengerr sends plain-text messages (typed as one line, or multi-line from a file) and HTML email from a file, with no attachments, and does not track delivery. It adds no unsubscribe links and does not check consent: laws such as CAN-SPAM, GDPR/PECR and the TCPA are the sender's responsibility. Credentials are stored in an encrypted file under `~/.config/messengerr`, with the key beside it by default, and `gem uninstall` does not remove them. Read [Limitations](https://jalappeno-apps.github.io/messengerr/limitations.html) and [Credentials](https://jalappeno-apps.github.io/messengerr/credentials.html) before a large send.

## Contributing

Bug reports and pull requests are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md) and [STYLE.md](STYLE.md).

## License

Released under the [MIT License](LICENSE).

Maintained by [Daiwick](https://daiwick.com). Questions and enquiries: developers@daiwick.com. Bugs and feature requests: [GitHub issues](https://github.com/jalappeno-apps/messengerr/issues). Security reports: see [SECURITY.md](SECURITY.md).
