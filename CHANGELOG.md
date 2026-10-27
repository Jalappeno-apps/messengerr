# Changelog

## 0.1.0 (unreleased)

First release. messengerr sends templated email and SMS to a CSV contact list from an interactive command line.

- `messengerr send`: an interactive wizard. Pick a delivery method and integration, write a message with `{{placeholders}}` (email subjects too), map columns, validate contacts, preview, confirm, send, and retry failures.
- Integrations: **Postmark** (email) and **ClickSend** (SMS), each with a live credential check and a sending-options class.
- `messengerr credentials setup|list|verify|delete`: credentials are verified against the provider and stored in an AES-256-GCM encrypted file under `~/.config/messengerr` (override with `MESSENGERR_CONFIG_DIR`). `MESSENGERR_MASTER_KEY` supplies the key instead of a key file.
- Safe by default: contacts are validated (email format, phone numbers normalised to E.164, `MESSENGERR_DEFAULT_COUNTRY`) and defects are listed by row to drop or abort on. Every message is rendered and previewed before sending, and anything with a leftover `{{` or `}}` aborts the run. `--dry-run` previews and sends nothing.
- A JSONL ledger records every result as it happens (mode `0600`). `--resume LEDGER` skips recipients already sent, matched by row number plus contact. Failures that may already have been delivered are marked uncertain and warned about before a retry or resume. Ctrl-C leaves an accurate ledger and exits `130`.
- One row is one message: repeated contacts are not de-duplicated.
- Flags: `--dry-run`, `--resume`, `--ledger`, `--batch-size`, `--rate-limit`, `--from`. Bad flags are reported cleanly. `messengerr send --help` lists them.
- Multi-line messages with `--message-file FILE` (email and SMS) and HTML email with `--html FILE` (Postmark). HTML is HTML only (no text part); CSV values are HTML-escaped; the first message is written to `messengerr-preview.html` for viewing in a browser; `--html` is refused for SMS and for integrations that cannot send HTML.
- UTF-8 CSVs, with or without a BOM, regardless of the shell's locale. Duplicate header names are rejected.
- Documentation site under `docs/`, including a reference generated from the integration registry (`rake docs:integrations`).
- Requires Ruby 3.2 or newer.
