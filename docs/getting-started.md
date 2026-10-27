---
title: Getting started
nav_order: 2
description: "Install messengerr, configure an email or SMS integration, preview a send with --dry-run, and send your first messages."
---

# Getting started
{: .no_toc }

From install to your first send in a few minutes.

<details open markdown="block">
  <summary>On this page</summary>
  {: .text-delta }
1. TOC
{:toc}
</details>

## Install

With [Homebrew](https://brew.sh) (macOS and Linux), which brings its own Ruby:

```sh
brew install Jalappeno-apps/messengerr/messengerr
messengerr --version
```

Or with RubyGems, which needs Ruby 3.2 or newer:

```sh
gem install messengerr
messengerr --version
```

## Configure an integration

An integration is the provider that actually delivers your messages. See what is available:

```sh
messengerr integrations
```

```text
email:
  postmark — not configured
sms:
  clicksend — not configured
```

Set one up. messengerr asks for each key, checks them against the provider's API, and only stores them if the check passes.

```sh
messengerr credentials setup postmark
```

```text
Setting up postmark (email):
server token:
from:
Postmark is configured and verified.
```

Your typing is not echoed back (nothing appears at all, not even asterisks), and every required key is prompted this way, including `from`. For ClickSend (SMS) the prompts are `username`, `api key`, and an optional `from`. Where the credentials are stored, and how, is covered in [Credentials]({{ '/credentials.html' | relative_url }}).

{: .note }
Postmark only sends from addresses you have verified in your Postmark account, so use a verified sender for `from`.

## Prepare a CSV

One row per message. The first row is the header. Any column can feed a placeholder.

```text
name,email,plan
Ann,ann@example.com,Pro
Bob,bob@example.com,Team
```

## Preview with a dry run

`--dry-run` walks the whole wizard and shows what would be sent, but sends nothing.

```sh
messengerr send --dry-run
```

You will be asked, in order:

1. Delivery method: `email` or `sms`.
2. The message. Use `{% raw %}{{name}}{% endraw %}`-style placeholders.
3. For email, the subject. Placeholders work here too.
4. The path to your CSV.
5. Which column feeds each placeholder, and which column holds the address or phone number.

You then see any bad contacts, and a preview of the first messages. The full walkthrough is in [Sending]({{ '/sending.html' | relative_url }}).

## Send for real

Run the same command without `--dry-run`. After the preview, messengerr asks `Send N message(s)? [y/n]`. Nothing leaves your machine until you answer `y`.

```sh
messengerr send
```

When it finishes you get a summary such as `Done — sent: 2, failed: 0, dropped: 1`, and a ledger file recording every result. If anything failed, you are offered a retry. If the run is interrupted, [resume it]({{ '/ledger-and-resume.html' | relative_url }}).

## Next

- [Writing messages and preparing CSVs]({{ '/csv-and-templates.html' | relative_url }})
- [Every command and flag]({{ '/command-line.html' | relative_url }})
- [Limitations]({{ '/limitations.html' | relative_url }}) worth knowing before a large send
