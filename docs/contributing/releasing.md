---
title: Releasing
parent: Contributing
nav_order: 4
description: "How to cut a messengerr release: version, changelog, checks, building and publishing the gem."
---

# Releasing
{: .no_toc }

Releases are cut by hand. There is no release workflow yet.

## Before tagging

1. Update `lib/messengerr/version.rb` and move the `CHANGELOG.md` entry from unreleased to the new version with a date.
2. Run everything:

   ```sh
   bundle exec rspec
   bundle exec rubocop
   bundle exec rake docs:check
   ```

3. Build the gem and look inside it:

   ```sh
   gem build messengerr.gemspec
   tar -xOf messengerr-X.Y.Z.gem data.tar.gz | tar -tz
   ```

   It should contain `lib/`, `exe/`, `README.md` and `LICENSE`, and **not** `docs/`, `spec/`, `AUDIT.md` or any ledger or credentials file.

4. Install the built gem into a scratch `GEM_HOME` and run `messengerr --version` and `messengerr integrations`.

## Publishing

The gemspec sets `rubygems_mfa_required`, so publishing needs a RubyGems account with multi-factor authentication.

```sh
git tag vX.Y.Z
git push origin vX.Y.Z
gem push messengerr-X.Y.Z.gem
```

## After

- The docs site deploys from `main` through the Docs workflow when `docs/**` changes. Confirm the new version's changelog page renders.
- A published version cannot be replaced. If something is wrong, yank it (`gem yank messengerr -v X.Y.Z`) and release a new version.
