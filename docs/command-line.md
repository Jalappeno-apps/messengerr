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
        --dry-run                    Preview the rendered messages; send nothing
        --resume LEDGER              Skip recipients already sent in this ledger (row + contact)
        --ledger PATH                Where to record results (default: ./messengerr-ledger-<time>.jsonl)
        --batch-size N               Messages per batch
        --rate-limit N               Batches per second
        --from ADDRESS               Override the sender address/ID
        --message-file FILE          Read a multi-line plain-text message from FILE instead of typing one line
        --html FILE                  Send FILE as an HTML email (email only; HTML only, no text version)
    -h, --help                       Show this help
```

| Flag | Notes |
|---|---|
| `--dry-run` | Runs the wizard, shows the preview, sends nothing, writes no ledger. |
| `--resume LEDGER` | The file must exist. Also becomes the ledger new results are appended to. See [Ledger and resume]({{ '/ledger-and-resume.html' | relative_url }}). |
| `--ledger PATH` | Where to write the ledger. Parent directories are created. |
| `--batch-size N` | A positive integer. Default `50`. ClickSend allows at most `1000`. |
| `--rate-limit N` | A positive integer. Default `10`. Counts **batches** per second, not messages (see [Limitations]({{ '/limitations.html' | relative_url }})). |
| `--from ADDRESS` | Overrides the `from` stored with the integration for this run. |
| `--message-file FILE` | Multi-line plain-text message, for email or SMS. Skips the message prompt. Cannot be combined with `--html`. See [HTML and multi-line messages]({{ '/html-email.html' | relative_url }}). |
| `--html FILE` | Sends the file as an HTML email. Email only, and only for integrations that can send HTML (Postmark). The first message is also written to `messengerr-preview.html`. |

Bad flags are reported as `messengerr: invalid option: --bogus (see 'messengerr send --help')` and exit `1` before any prompt. Stray arguments (`messengerr send file.csv`) are rejected the same way: the CSV path is asked for inside the wizard.

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
