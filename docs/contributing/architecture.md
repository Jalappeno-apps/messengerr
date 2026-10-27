---
title: Architecture
parent: Contributing
nav_order: 1
description: "How a messengerr send flows through the code, and what the main classes are responsible for."
---

# Architecture
{: .no_toc }

<details open markdown="block">
  <summary>On this page</summary>
  {: .text-delta }
1. TOC
{:toc}
</details>

## Loading

`lib/messengerr.rb` sets up a Zeitwerk loader for the gem, so file paths map to constants. Two inflections are registered (`cli` is `CLI`, `clicksend` is `ClickSend`). `version.rb` and `errors.rb` are required directly. `Messengerr.register_integration` is the hook third-party code uses to add an integration.

## How `messengerr send` flows

`CLI::SendCommand#run` is a linear pipeline. Each step is a small private method.

1. **Flags.** `OptionParser` fills a flags hash. Bad flags become a `Messengerr::Error`. `--resume` must point at a file that exists.
2. **Delivery method and integration.** `Registry.configured_by_method` lists integrations that have stored credentials.
3. **Message.** A single line for the body, and for email a subject. Both may contain placeholders.
4. **CSV.** `CsvSource.from` returns headers and rows (UTF-8 with optional BOM; duplicate headers rejected).
5. **Mapping.** `Placeholder.extract` finds the names in the body and subject. The user maps each to a column and picks the contact column.
6. **Validation.** `ContactValidator.validate` returns `Recipient`s and `Defect`s. The user drops the defects or aborts.
7. **Preview and confirm.** `Renderer.render` turns each recipient into a `Delivery` (body and subject). Any failure aborts. With `--resume`, recipients already `sent` in the ledger are filtered out and earlier uncertain attempts are warned about. The user sees the count and the first messages, then confirms.
8. **Send.** The integration is built from the stored credentials. The options class is instantiated and the CLI-settable options (`CLI_OPTIONS`) are applied. A `Ledger` is created and checked for writability. `Sender#deliver` does the work.
9. **Retry and report.** Failures are listed. The user may retry only the failed recipients. `Report` produces the summary and the exit code.

## The pieces

| Piece | Responsibility |
|---|---|
| `Registry` | Lookup of registered integration classes. Built-ins register as Zeitwerk loads them. Two integrations cannot share a key. |
| `Integrations::Base` | The provider contract: `delivery_method`, `send_batch`, `verify!`. Names the parallel `Setups::` and `SendingOptions::` classes by convention. |
| `Setups::Base` | Prompts for credentials, verifies them live, stores them. |
| `SendingOptions::Base` | Per-integration options (`from`, `batch_size`, `rate_limit`, plus its own) with `validate!`. |
| `Sender` | Splits deliveries into batches, throttles, calls the integration, and guarantees **one `Result` per `Delivery`**: exceptions become failed results, missing results are filled in as uncertain, results the integration `yield`s are recorded immediately, Ctrl-C marks unreported sends uncertain, and a ledger write failure halts further batches. |
| `Ledger` | The JSONL record. Appends per result, mode `0600`. Reads it back for `--resume` keyed by `[row_number, contact]`. |
| `Credentials`, `Crypto`, `Paths` | The encrypted credentials file, AES-256-GCM, and where the files live. |
| `Prompter` | Injectable input and output. Commands never read or write the terminal directly. |
| `Report` | Counts for the final summary and the exit code. |
| Value objects | `Recipient`, `Delivery`, `Result`, `ContactValidator::Defect`, all `Data.define`. |

## Failure model

A failed send is either **definite** (the provider rejected it) or **uncertain** (it may have been accepted). `Result#uncertain` carries that. `IntegrationError` means definite and its subclass `UncertainError` means uncertain. Integrations set the flag per result, and `Sender` sets it for anything that escapes an integration. Everything that decides whether to warn before a retry reads this one flag.
