---
title: Troubleshooting
nav_order: 10
description: "Error messages you may see from messengerr, what each one means, and how to fix it."
---

# Troubleshooting
{: .no_toc }

Errors are printed as `messengerr: <message>` and the command exits with code `1`. Find the message below.

<details open markdown="block">
  <summary>On this page</summary>
  {: .text-delta }
1. TOC
{:toc}
</details>

## Setup and credentials

**`No email integrations are configured.` / `Run 'messengerr credentials setup <name>' first.`**
: You chose a delivery method with no configured integration. Run `messengerr integrations` to see what is available, then `messengerr credentials setup NAME`.

**`Unknown integration 'x'. Available: clicksend, postmark`**
: Check the spelling. The names come from `messengerr integrations`.

**`Verification failed: ...`** (during setup), **`Postmark verification failed: ...`**, **`ClickSend verification failed (401)`**
: The provider rejected the credentials. Re-enter them. For Postmark, use a *server* token. For ClickSend, the username and API key from your API credentials page.

**`ClickSend unreachable: ...`**
: messengerr could not reach ClickSend (no network, DNS, a proxy, or TLS trouble). Check your connection and try again.

**`All required fields must have a value — aborting.`**
: A required prompt was left empty.

**`credentials could not be decrypted — master key is missing or incorrect`**
: The key does not match the file. Either `MESSENGERR_MASTER_KEY` is set to a different value than the one used to store the credentials, or `master.key` was replaced. Restore the original key, or run `messengerr credentials delete` and set up again.

**`credentials exist but no master key is available — set MESSENGERR_MASTER_KEY or run 'messengerr credentials delete' to reset`**
: The credentials file exists but `master.key` is gone and `MESSENGERR_MASTER_KEY` is not set.

**`MESSENGERR_MASTER_KEY must be 64 hex characters (32 bytes)`**
: The variable is set to something else, or is set but empty. Generate a valid one: `ruby -rsecurerandom -e 'puts SecureRandom.hex(32)'`. Unset it to use the key file instead.

**`.../master.key is malformed — run 'messengerr credentials delete --purge' to reset`**
: The key file is not 64 hex characters. If you have the original, restore it. Otherwise purge and set up again.

**`credentials file is truncated or malformed`** / **`credentials file decrypted to invalid YAML — it may be corrupted`**
: The file was damaged. Delete it with `messengerr credentials delete` and run `setup` again.

**`cannot write .../credentials.yml.enc — check permissions on ...`**
: messengerr cannot write to its config directory. Fix the permissions, or point `MESSENGERR_CONFIG_DIR` at a directory you own.

## Your CSV and message

**`CSV file not found: PATH`**
: The path is wrong, or it is a directory. `~` is expanded. Relative paths are relative to where you ran messengerr.

**`could not parse CSV PATH: Invalid byte sequence in UTF-8 ...`**
: The file is not UTF-8 (often Latin-1 from older spreadsheet exports). Re-save it as UTF-8. A byte-order mark is fine.

**`CSV has duplicate headers: name`**
: Two columns share a name. Rename one in the CSV.

**`CSV has no header row`**
: The first row is empty. The first row must hold column names.

**`row N: column "plan" is empty for {% raw %}{{plan}}{% endraw %}`** then `Aborted — fix the CSV or mapping and try again.`
: A row has no value for a placeholder. Fill the cell, remove the row, or change the message.

**`row N: no column mapped for placeholder {% raw %}{{x}}{% endraw %}`**
: A placeholder was not mapped. This normally means the wizard was bypassed. Re-run it.

**`row N: unrenderable placeholder left in message: {% raw %}{{first-name}}{% endraw %}`**
: A `{% raw %}{{ }}{% endraw %}` pair remained after substitution, usually from a placeholder name with a hyphen or space. Use letters, digits and underscores, for example `{% raw %}{{first_name}}{% endraw %}`. See [CSV and templates]({{ '/csv-and-templates.html' | relative_url }}).

**`invalid phone number` for every row**
: Numbers need a country code (`+44...`), or set `MESSENGERR_DEFAULT_COUNTRY` (for example `GB`) for local formats.

**`No valid contacts to send to — aborting.`**
: Every row failed validation, or you dropped them all. Check you chose the right contact column.

## Sending

**`messengerr: invalid option: --x (see 'messengerr send --help')`** / **`invalid argument: --batch-size 0 (must be a positive integer)`**
: A flag is wrong. Run `messengerr send --help`.

**`batch_size can't exceed 1000 for ClickSend`**
: Lower `--batch-size`.

**`cannot write ledger PATH: ...`**
: messengerr will not send what it cannot record. Choose a writable path with `--ledger`.

**`Stopped early: ledger write failed (...); stopped so no message goes unrecorded`**
: The ledger became unwritable mid-run (disk full, permissions). Messages already sent are in the failure/summary list. Free space or fix permissions and use `--resume`. Recipients shown as `not sent — ledger write failed` were never attempted.

**`subject is required for email sends`**
: A message reached the provider with no subject. The wizard re-asks for a blank subject, so this only appears with custom code.

**`unexpected end of input`**
: The wizard needed an answer but standard input closed (for example when piping input that ran out).

**A failure marked `[uncertain — may already be delivered]`**
: The provider may have accepted it. Check the provider's activity log before retrying. See [Ledger and resume]({{ '/ledger-and-resume.html' | relative_url }}).

**`ClickSend rejected the request (4xx): ...`**
: ClickSend refused the whole batch with a 4xx response (for example bad credentials or invalid parameters). The response text after the status code says why. Fix that, then retry.

**`integration returned no result`**
: An integration did not report a recipient. The message may or may not have been sent. Treat it as uncertain.

## Resuming

**`resume ledger not found: PATH`**
: The `--resume` path does not exist. messengerr refuses to guess, because a typo would otherwise re-send to everyone.

**`Resuming: 0 already sent, N remaining.`** when you expected skips
: Recipients are matched by row number and contact. If the CSV changed since the run, or you pointed at the wrong ledger, nothing matches. See [Ledger and resume]({{ '/ledger-and-resume.html' | relative_url }}).

## Still stuck?

Open an issue at [github.com/jalappeno-apps/messengerr](https://github.com/jalappeno-apps/messengerr/issues) with the command you ran and the message you saw. Do not paste credentials or a ledger (it holds contact details).
