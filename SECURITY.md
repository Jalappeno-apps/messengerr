# Security

## Reporting a vulnerability

Please **do not open a public issue** for a security problem.

Report it privately, using either of:

- GitHub's private vulnerability reporting: open the repository's **Security** tab, then **Report a vulnerability**.
- Email developers@daiwick.com with "messengerr security" in the subject.

Include what you found, the version (`messengerr --version`), and steps to reproduce it. **Never include real credentials, API keys, or contact lists.** Redact them.

We will acknowledge your report, look into it, and tell you what we plan to do. Please give us a reasonable time to fix a problem before you disclose it publicly.

## Supported versions

messengerr is at version 0.x. Security fixes are made in the latest release only.

## What is in scope

messengerr sends messages to real people, so these matter most:

- Anything that exposes stored provider credentials or the master key.
- Anything that sends a message the user did not preview and confirm, or sends to the wrong recipients.
- Markup or script injection through CSV values in HTML emails.
- Leaking secrets or contact details into logs, error messages, command-line arguments, or the ledger.

How credentials are stored, and what that does and does not protect against, is documented in the [credentials guide](https://jalappeno-apps.github.io/messengerr/credentials.html). Please read it first: by default the master key is kept beside the encrypted file, which is a documented limit and not a vulnerability in itself.
