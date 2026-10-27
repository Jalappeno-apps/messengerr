---
title: Limitations
nav_order: 12
description: "What messengerr does not do yet: message format limits, rate limiting semantics, credential storage, resume caveats, and compliance responsibilities."
---

# Limitations
{: .no_toc }

messengerr is young. These are the things worth knowing before a large send.

<details open markdown="block">
  <summary>On this page</summary>
  {: .text-delta }
1. TOC
{:toc}
</details>

## Messages

- **Typed messages are one line.** The message and subject you type are one line each. For a multi-line message, use `--message-file`.
- **HTML email is HTML only.** `--html` sends an HTML body and no plain-text part, and nothing is generated for clients that prefer text. It works for email through Postmark only. See [HTML and multi-line messages]({{ '/html-email.html' | relative_url }}).
- **No attachments, inline images, CC/BCC or reply-to.** Images in HTML must be hosted at a public address.
- **No conditionals or logic.** Templates only insert values. `if`, loops, filters and expressions inside `{% raw %}{{ }}{% endraw %}` are not supported and abort the run. See [CSV and templates]({{ '/csv-and-templates.html' | relative_url }}).
- **No literal `{% raw %}{{` or `}}{% endraw %}`.** Those pairs are always treated as placeholders. See [CSV and templates]({{ '/csv-and-templates.html' | relative_url }}).
- **SMS segment counts are estimates.** The preview assumes standard 160/153-character segments. Emoji and many accented characters use shorter ones, so the real count and cost can be higher.

## Sending

- **"Sent" means accepted, not delivered.** messengerr records that the provider accepted the message. It does not track delivery, bounces or opens.
- **`--rate-limit` counts batches, not messages.** Postmark messages are sent one at a time inside a batch, so with defaults the speed is set by the network. To slow down, shrink the batch: `--batch-size 1 --rate-limit 5` sends about five messages a second.
- **The CSV is read fully into memory.** Very large files (hundreds of thousands of rows) need memory to match.
- **A real send needs a terminal.** Without one (a pipe, CI, an automated shell) a send is refused unless you pass `--allow-non-interactive`. Previews (`--dry-run`) work anywhere. The check is a safety net for accidents: it tests whether standard input is a terminal, and a program can fake one, so it is not a security boundary.
- **No config file.** Flags answer the wizard's questions, but there is no file to store a send's settings. Keep the command in a script.
- **Sending options.** Provider options such as Postmark's `message_stream`, `tag` and `track_opens`, and ClickSend's `schedule`, exist in the library but cannot be set from the command line yet.

## Resume

- **Resume matches on row number plus contact**, so the CSV must be unchanged between a run and its resume. See [Ledger and resume]({{ '/ledger-and-resume.html' | relative_url }}).
- The ledger does not store your message or mapping, so you re-enter them.

## Credentials

- Stored in an encrypted file with the master key beside it by default. This protects the file on its own, not against anything that can read your files as you. See [Credentials]({{ '/credentials.html' | relative_url }}).
- No per-integration environment variables and no operating-system keychain.
- `gem uninstall` does not remove stored credentials. Run `messengerr credentials delete --purge` first.
- Developed on macOS. Linux is expected to work. Windows is untested.

## Integrations

- Email (Postmark) and SMS (ClickSend) only.
- Third-party integrations must be loaded by hand (for example with `RUBYOPT`). There is no automatic plugin discovery. See [Writing an integration]({{ '/writing-an-integration.html' | relative_url }}).
- Only the `email` and `sms` delivery methods exist in the wizard.

## Compliance is your responsibility

messengerr sends what you tell it to. It does not add unsubscribe links, check consent, honour opt-outs or keep suppression lists. Laws such as CAN-SPAM, GDPR/PECR and the TCPA apply to the person sending. Make sure you have the right to message everyone on your list, and that your messages include whatever the law requires.
