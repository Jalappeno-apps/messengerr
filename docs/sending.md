---
title: Sending
nav_order: 3
description: "The messengerr send wizard step by step: choosing an integration, validating contacts, previewing, confirming, retrying failures, and the exit codes."
---

# Sending
{: .no_toc }

`messengerr send` is an interactive wizard. This page walks through it in order.

<details open markdown="block">
  <summary>On this page</summary>
  {: .text-delta }
1. TOC
{:toc}
</details>

## Delivery method and integration

You choose `email` or `sms`. messengerr then looks for configured integrations for that method. With exactly one, it uses it. With several, it asks which.

If none is configured you see:

```text
No email integrations are configured.
Run `messengerr credentials setup <name>` first.
```

## The message

By default the message is a single line you type. Use `{% raw %}{{column}}{% endraw %}` placeholders, for example `Hi {% raw %}{{name}}{% endraw %}, your {% raw %}{{plan}}{% endraw %} invoice is ready.` For email you are also asked for a **subject**, and the subject can contain placeholders too. A blank subject is not accepted: you are asked again.

For a multi-line message, or an HTML email, start the command with `--message-file FILE` or `--html FILE` and the wizard skips this prompt. See [HTML and multi-line messages]({{ '/html-email.html' | relative_url }}).

See [CSV and templates]({{ '/csv-and-templates.html' | relative_url }}) for the exact placeholder rules.

## The CSV and the mapping

You give the path to a local CSV file. messengerr prints its columns, then asks you to pick the column for each placeholder, and finally which column holds the email address or phone number.

## Contact validation

Every row's contact is checked. Rows that fail are listed with their row number (the header is row 1):

```text
1 contact(s) have defects:
  row 4: "not-an-email" — invalid email address
Drop these contacts and continue? (n = abort to fix) [y/n]
```

Answer `y` to drop the listed rows and carry on, or `n` to abort so you can fix the file. If nothing valid is left, the run stops with `No valid contacts to send to — aborting.`

## Preview and confirmation

Before anything is sent, every message is rendered. If any row cannot be rendered (an unmapped placeholder, or an empty cell for a placeholder), the run aborts and tells you which row, so a half-filled message never goes out.

Then you see the total and the first three messages (an HTML message shows its size instead of its markup, and the first one is written to `messengerr-preview.html` so you can open it in a browser):

```text
--- Preview (2 messages) ---
To: ann@example.com
Subject: Invoice for Ann
Body: Hi Ann, your Pro invoice is ready.
...
Send 2 message(s)? [y/n]
```

For SMS, each preview also shows an estimated segment count. Answer `n` and nothing is sent. With `--dry-run` the confirmation is skipped because nothing will be sent either way.

{: .note }
The SMS segment estimate assumes the standard 160/153-character limits. Messages with emoji or non-GSM characters use shorter segments, so the real count, and cost, can be higher. See [Limitations]({{ '/limitations.html' | relative_url }}).

## Sending

Messages go out in batches (default 50 per batch, at most 10 batches per second). Each result is written to the [ledger]({{ '/ledger-and-resume.html' | relative_url }}) as it lands. A failure for one recipient never stops the others.

## Failures and retry

Failures are listed with their row, contact and reason:

```text
2 send(s) failed:
  row 5 (carol@example.com): Invalid email
  row 9 (+15551234567): ClickSend connection lost mid-request (status unknown): ... [uncertain — may already be delivered]
Warning: some failures are uncertain — retrying may send duplicates.
Retry failed sends? [y/n]
```

A failure marked **uncertain** means the provider may have accepted the message even though messengerr did not get a clear answer (a timeout, a dropped connection, a server error). Retrying those can send a duplicate. A failure without that mark was definitely rejected. See [Ledger and resume]({{ '/ledger-and-resume.html' | relative_url }}).

You can retry as many times as you like. Only the failed recipients are sent again.

## The result

```text
Ledger written to ./messengerr-ledger-20261027-091500.jsonl
Done — sent: 2, failed: 0, dropped: 1
```

`dropped` counts the contacts you removed at the validation step.

## Scripting a send

Every wizard question has a flag (see the [command line reference]({{ '/command-line.html' | relative_url }})), so a whole send can be one command. Preview it first:

```sh
messengerr send --method email --csv contacts.csv --contact email \
  --map name=name --map plan=plan \
  --message-file letter.txt --subject "Hello, {% raw %}{{name}}{% endraw %}" --dry-run
```

This works anywhere, including a script or an automated shell. It prints the preview and sends nothing. When the preview is right, run **the same command without `--dry-run`**, in a terminal window. messengerr shows the preview again and asks you to confirm.

A real send is refused when there is no terminal, so an automated shell can prepare and preview but never send. If you do want a script to send, pass `--allow-non-interactive`, and see [Limitations]({{ '/limitations.html' | relative_url }}).

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Everything was sent, or `--dry-run` completed. |
| `1` | Some sends failed, you aborted, or an error stopped the run (printed as `messengerr: ...`). |
| `130` | You pressed Ctrl-C. The ledger and a `--resume` command are printed. |
