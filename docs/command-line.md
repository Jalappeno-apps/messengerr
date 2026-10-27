---
title: Command line
nav_order: 8
description: "Reference for every messengerr command, flag, environment variable, and exit code."
---

# Command line
{: .no_toc }

<details open markdown="block">
  <summary>On this page</summary>
  {: .text-delta }
1. TOC
{:toc}
</details>

## Commands

```text
messengerr credentials setup|list|verify|delete [--purge]
messengerr send [flags]
messengerr integrations
messengerr --help | -h
messengerr --version | -v
```

| Command | What it does |
|---|---|
| `credentials setup NAME` | Prompt for the integration's credentials, verify them live, and store them encrypted. |
| `credentials list` | List registered integrations and whether each is configured. |
| `credentials verify NAME` | Re-check stored credentials against the provider's API. |
| `credentials delete [--purge]` | Delete the credentials file after confirmation. `--purge` also deletes the master key. |
| `send` | The interactive send wizard. See [Sending]({{ '/sending.html' | relative_url }}). |
| `integrations` | List integrations grouped by delivery method, with their configured state. |

An unknown command prints `messengerr: unknown command '...'` plus the usage and exits `1`.

## `send` flags

```text
Usage: messengerr send [flags]
        --method METHOD              Delivery method (skips the chooser)
        --integration NAME           Integration to use (e.g. postmark, clicksend)
        --dry-run                    Preview the rendered messages; send nothing
        --csv PATH                   Contact CSV (skips the path prompt)
        --contact COLUMN             Column holding the email/phone contact value
        --map PLACEHOLDER=COLUMN     Map a {% raw %}{{placeholder}}{% endraw %} to a CSV column (repeatable)
        --message TEXT               Message body as a literal argument
        --subject TEXT               Email subject line ({% raw %}{{placeholders}}{% endraw %} allowed)
        --allow-non-interactive      Send without an interactive terminal (human scripts only)
        --resume LEDGER              Skip recipients already sent in this ledger (row + contact)
        --ledger PATH                Where to record results (default: ./messengerr-ledger-<time>.jsonl)
        --batch-size N               Messages per batch
        --rate-limit N               Batches per second
        --from ADDRESS               Override the sender address/ID
        --message-file FILE          Read a multi-line plain-text message from FILE instead of typing one line
        --html FILE                  Send FILE as an HTML email (email only; HTML only, no text version)
    -h, --help                       Show this help
```

Most flags **answer a wizard question in advance**. Anything you leave out is still asked, so you can mix flags and prompts. A flag is validated exactly like the prompt it replaces.

### Answering the wizard in advance

| Flag | Replaces the prompt for | Notes |
|---|---|---|
| `--method email\|sms` | Delivery method | |
| `--integration NAME` | Which integration (when several are configured) | Must be configured for the chosen method, or the run stops with `Integration 'NAME' is not configured for METHOD.` |
| `--csv PATH` | Path to the CSV | `~` is expanded. |
| `--contact COLUMN` | The email/phone column | Must be a header in the CSV: `--contact X: no such column in the CSV.` |
| `--map PLACEHOLDER=COLUMN` | Mapping a placeholder | Repeat for each placeholder, in the message **and** the subject. The column must exist. A mapping for a placeholder that isn't in the message or subject prints `Note: --map X not used`, which is usually a typo. |
| `--message TEXT` | The message (one line) | Not with `--message-file` or `--html`. Quote it so your shell keeps it as one argument. |
| `--subject TEXT` | The email subject | Email only: `--subject is only for email; SMS messages have no subject`. Placeholders allowed. |

None of these may be blank (`--message can't be blank`). That catches an empty shell variable before it becomes an empty message.

### Other flags

| Flag | Notes |
|---|---|
| `--dry-run` | Runs the wizard, shows the preview, sends nothing, writes no ledger. **Works without a terminal.** |
| `--allow-non-interactive` | Lets a real send run without a terminal (see [a real send needs a terminal](#a-real-send-needs-a-terminal)). For your own scripts. |
| `--resume LEDGER` | The file must exist. Also becomes the ledger new results are appended to. See [Ledger and resume]({{ '/ledger-and-resume.html' | relative_url }}). |
| `--ledger PATH` | Where to write the ledger. Parent directories are created. |
| `--batch-size N` | A positive integer. Default `50`. ClickSend allows at most `1000`. |
| `--rate-limit N` | A positive integer. Default `10`. Counts **batches** per second, not messages (see [Limitations]({{ '/limitations.html' | relative_url }})). |
| `--from ADDRESS` | Overrides the `from` stored with the integration for this run. |
| `--message-file FILE` | Multi-line plain-text message, for email or SMS. Skips the message prompt. Cannot be combined with `--html` or `--message`. See [HTML and multi-line messages]({{ '/html-email.html' | relative_url }}). |
| `--html FILE` | Sends the file as an HTML email. Email only, and only for integrations that can send HTML (Postmark). The first message is also written to `messengerr-preview.html`. |

Bad flags are reported as `messengerr: invalid option: --bogus (see 'messengerr send --help')` and exit `1` before any prompt. Stray arguments (`messengerr send file.csv`) are rejected the same way.

### A real send needs a terminal

A send that is not a `--dry-run` is refused unless standard input is an interactive terminal:

```text
messengerr: refusing to send without an interactive terminal: run `messengerr send` yourself in a terminal (or pass --allow-non-interactive in your own scripts). --dry-run works anywhere.
```

This stops an automated shell, a CI job or a pipe from sending by accident, for example an AI assistant running commands for you. Nothing is read or written before the refusal. In a normal terminal window you never see it.

- **`--dry-run` is always allowed**, with or without a terminal, so you can script previews.
- **`--allow-non-interactive`** is the deliberate opt-out for your own scripts. Prefer it only when you have already reviewed the preview.
- This is a safety net against accidents, not a security boundary: a program can fake a terminal.

Other sending options the integrations support, such as Postmark's `message_stream` and `tag`, are not exposed on the command line yet. See the [integrations reference]({{ '/integrations.html' | relative_url }}).

## Environment variables

| Variable | Purpose |
|---|---|
| `MESSENGERR_DEFAULT_COUNTRY` | Country (for example `US`) used to interpret SMS numbers written without a country code. |
| `MESSENGERR_CONFIG_DIR` | Directory for the credentials file and master key. Default `~/.config/messengerr`. |
| `MESSENGERR_MASTER_KEY` | A 64-character hex master key, used instead of a key file. See [Credentials]({{ '/credentials.html' | relative_url }}). |

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success. For `send`: everything was sent, or `--dry-run` completed. |
| `1` | Failure: some sends failed, you aborted, a validation or configuration error occurred. |
| `130` | `send` was interrupted with Ctrl-C. |
