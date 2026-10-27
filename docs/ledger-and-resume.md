---
title: Ledger and resume
nav_order: 7
description: "The messengerr send ledger records every result as it happens. How --resume skips recipients already sent, what uncertain failures are, and what Ctrl-C does."
---

# Ledger and resume
{: .no_toc }

A bulk send can be interrupted by a crash, a lost connection, or Ctrl-C. The ledger is how messengerr makes sure you always know who was messaged.

<details open markdown="block">
  <summary>On this page</summary>
  {: .text-delta }
1. TOC
{:toc}
</details>

## The ledger

Every real send writes a ledger: a JSON Lines file with one line per result, appended **as each result arrives**, not at the end.

By default it is created in the current directory as `messengerr-ledger-YYYYMMDD-HHMMSS.jsonl` (UTC time). Choose a path with `--ledger PATH`.

```json
{"row_number":2,"contact":"ann@example.com","status":"sent","reason":null,"provider_id":"abc-123","uncertain":false,"sent_at":"2026-10-27T09:15:02Z"}
{"row_number":5,"contact":"carol@example.com","status":"failed","reason":"Invalid email","provider_id":null,"uncertain":false,"sent_at":"2026-10-27T09:15:03Z"}
```

| Field | Meaning |
|---|---|
| `row_number` | The CSV row (the header is row 1). |
| `contact` | The normalised address or E.164 number. |
| `status` | `sent` or `failed`. |
| `reason` | Why it failed, or `null`. |
| `provider_id` | The provider's message ID when it gave one. |
| `uncertain` | `true` if a failure may still have been delivered. |
| `sent_at` | When the result was recorded (UTC). |

The ledger is created with mode `0600` because it contains your contacts' addresses and numbers. It does not contain message text or credentials. Delete it when you no longer need it. `--dry-run` writes no ledger.

Before anything is sent, messengerr checks that the ledger can be written, and stops with `cannot write ledger PATH: ...` if not. If writing fails part-way through, messengerr stops sending further batches rather than send messages it cannot record, and reports `Stopped early: ...`.

## Uncertain failures

A send can fail in two ways:

- **Definitely failed.** The provider rejected it (for example an invalid address or bad credentials). Safe to retry once the cause is fixed.
- **Uncertain.** messengerr did not get a clear answer: a timeout after the request was sent, a dropped connection, a server error (5xx), or an unreadable response. The provider may have accepted the message. Retrying can send a duplicate.

Uncertain failures are labelled in the failure list and in the ledger (`"uncertain": true`), and messengerr warns you before you retry them. For each provider:

| Provider | Definite | Uncertain |
|---|---|---|
| ClickSend | 4xx responses (including 429), and failures to connect (timeout opening the connection, refused, DNS, TLS handshake) | 5xx responses (including 502/504), unreadable responses, read/write timeouts, connection resets, a missing per-message status |
| Postmark | 4xx responses (for example an invalid or inactive address) | Timeouts, 5xx responses, connection errors, anything unrecognised |

## Resuming a run

```sh
messengerr send --resume messengerr-ledger-20261027-091500.jsonl
```

Run the wizard again with the **same CSV**. messengerr skips every recipient the ledger already records as `sent`, tells you how many it skipped (`Resuming: 40 already sent, 60 remaining.`), shows the preview for the rest, and asks for confirmation as usual. New results are appended to the same ledger.

How recipients are matched:

- A recipient is identified by **row number plus contact**. If the same address appears on rows 2 and 5 and only row 2 was sent, row 5 is still sent. One row is one message.
- Because row numbers are part of the match, **do not edit the CSV between the run and its resume**. Inserting or deleting rows shifts the numbers, so the wrong rows could be skipped or re-sent.
- The ledger does not store your message or column mapping, so you enter those again.

If the ledger path does not exist, messengerr stops with `resume ledger not found: PATH` instead of treating it as "nothing sent yet".

### Recipients with an unknown outcome

If an earlier attempt for a recipient ended uncertain and never later succeeded, `--resume` sends to them again, and says so first:

```text
Warning: 2 contact(s) had an earlier attempt with an unknown outcome and will be sent again — they may receive duplicates:
  carol@example.com
  dave@example.com
```

You see this before the final confirmation. If duplicates would be a problem, answer `n` and check with your provider (for example its activity log) before continuing.

## Pressing Ctrl-C

If you interrupt a send:

- Everything already reported is in the ledger.
- Messages that were in flight and had not reported back are recorded as failed and uncertain with the reason `interrupted`.
- messengerr prints the ledger path and the exact `messengerr send --resume ...` command, and exits with code `130`.

Postmark sends messages one at a time and records each as it finishes. ClickSend sends a batch in a single request, so an interrupt during that request makes the whole batch uncertain.
