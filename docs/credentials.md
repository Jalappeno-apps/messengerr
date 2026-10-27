---
title: Credentials
nav_order: 6
description: "Where messengerr stores integration credentials, how they are encrypted, what that does and does not protect against, and how to remove them."
---

# Credentials
{: .no_toc }

<details open markdown="block">
  <summary>On this page</summary>
  {: .text-delta }
1. TOC
{:toc}
</details>

## Managing credentials

```sh
messengerr credentials setup postmark   # prompt, verify live, store
messengerr credentials list             # what is registered and configured
messengerr credentials verify postmark  # re-check the stored credentials against the API
messengerr credentials delete           # remove the credentials file
messengerr credentials delete --purge   # also remove the master key
```

`setup` asks for each key, calls the provider's API to check them, and stores them only if the check passes. If verification fails you are offered another attempt. Running `setup` for an integration that is already configured replaces its stored values without asking.

Required keys are read without echoing your typing. Optional keys (for example ClickSend's `from`) can be skipped with Enter.

## Where they are stored

| What | Default location |
|---|---|
| Encrypted credentials | `~/.config/messengerr/credentials.yml.enc` |
| Master key | `~/.config/messengerr/master.key` |

Set `MESSENGERR_CONFIG_DIR` to use a different directory. A blank value is ignored.

The directory is created with mode `0700` and both files with `0600`. Files are written atomically (a temporary file, then a rename), so a crash cannot leave a truncated credentials file. A directory that already exists is never changed.

Credentials live outside the gem directory, so they **survive upgrades**.

## How they are encrypted

The file is YAML encrypted with AES-256-GCM, with a fresh random IV for every write. The key is a random 32-byte master key, stored as 64 hex characters.

### Supplying the master key yourself

Set `MESSENGERR_MASTER_KEY` to a 64-character hex string and messengerr uses it instead of a key file, and never writes one:

```sh
export MESSENGERR_MASTER_KEY=$(ruby -rsecurerandom -e 'puts SecureRandom.hex(32)')
```

Rules:

- It must be exactly 64 hex characters (surrounding whitespace is ignored). Anything else, including an empty value, is an error: `MESSENGERR_MASTER_KEY must be 64 hex characters (32 bytes)`. messengerr does not silently fall back to a key file.
- The error never prints the value you set.
- Credentials encrypted with one key cannot be read with another: you get `credentials could not be decrypted — master key is missing or incorrect`. Keep the key safe. If it is lost, `credentials delete` and set the integration up again.

## What this does and does not protect

{: .important }
By default the master key sits in the same directory as the file it unlocks. Anyone, or any program, that can read your files as your user can read both. In that case the encryption adds little over a `0600` plain file.

What it **does** give you:

- The credentials file is useless on its own. If it is copied, backed up without the key, or committed by accident, the secrets are not exposed.
- Secrets never appear in command-line arguments, logs, or the send ledger.

What it does **not** do:

- Stop malware or another process running as you from reading both files.
- Protect a machine where others can read your home directory.

To keep the key away from the file, provide `MESSENGERR_MASTER_KEY` from a secret manager or your shell environment, so it is never written beside the credentials.

## Removing credentials

`gem uninstall messengerr` does **not** remove your credentials. They live in your config directory, not in the gem. To remove them:

```sh
messengerr credentials delete --purge   # asks for confirmation
```

That deletes the credentials file and the master key. The (now empty) directory is left behind and can be removed by hand. If you have already uninstalled the gem, delete `~/.config/messengerr` (or your `MESSENGERR_CONFIG_DIR`) yourself.

## Not supported yet

- Per-integration environment variables (for example `MESSENGERR_POSTMARK_TOKEN`). Credentials come only from the encrypted file. To use messengerr in CI you must provide that file and `MESSENGERR_MASTER_KEY`.
- Operating-system keychains.
- The file handling is developed on macOS. Linux is expected to work and Windows is untested.
