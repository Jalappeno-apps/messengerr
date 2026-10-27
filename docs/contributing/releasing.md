---
title: Releasing
parent: Contributing
nav_order: 4
description: "How messengerr is published to RubyGems: one-time setup for trusted publishing, the tag-based release, and how to recover from a bad release."
---

# Releasing
{: .no_toc }

Pushing a version tag publishes the gem to RubyGems through GitHub Actions. Nothing is stored in the repository that could publish it: the release job proves its identity to RubyGems with a short-lived token ([trusted publishing](https://guides.rubygems.org/trusted-publishing/)).

<details open markdown="block">
  <summary>On this page</summary>
  {: .text-delta }
1. TOC
{:toc}
</details>

{: .important }
A published version can never be replaced or reused. If something is wrong you can only [yank](#if-something-goes-wrong) it and publish a new version. Check everything before you push the tag.

## One-time setup

Do this once, before the first release. It needs people with the right access, so it cannot be done from the repository alone.

### 1. RubyGems account and owners

A GitHub organisation cannot own a gem. RubyGems ownership belongs to user accounts, so the organisation is represented by accounts:

1. **A dedicated Daiwick account** on a mailbox the team controls. It owns the gem and is the account that registers the trusted publisher. Turn on multi-factor authentication (the gem requires it to publish: `rubygems_mfa_required`), register a second device, and keep the recovery codes in the company password manager where at least two people can reach them. Check RubyGems' terms for shared or role accounts.
2. **Named teammates as additional owners**, added right after the first release (`gem owner messengerr --add EMAIL`, or the gem's **Ownership** page), each with their own MFA. Two or more owners means no single account is the only way to manage the gem.

Releases are published by the workflow, not by anyone's login, so the shared account is only needed for administration.

**RubyGems Organizations.** RubyGems has an Organizations feature with owner, admin and maintainer roles. As of early 2026 it is in private beta: teams apply through the interest form in [the announcement](https://blog.rubygems.org/2026/02/16/organizations-beta.html). The gem can move into an organisation later without being republished.

### 2. Register a pending trusted publisher

Because the gem does not exist yet, register a *pending* publisher so the first release can also be done without an API key. On RubyGems.org open your profile, then **Trusted publishers**, add a pending publisher with:

| Field | Value |
|---|---|
| Gem name | `messengerr` |
| Repository owner | `Jalappeno-apps` (exactly as GitHub shows it) |
| Repository name | `messengerr` |
| Workflow filename | `release.yml` |
| Environment | `rubygems` |

After the first successful release the pending entry becomes a normal trusted publisher for the gem. See RubyGems' guide to [pushing a new gem](https://guides.rubygems.org/trusted-publishing/pushing-a-new-gem).

### 3. Create the GitHub environment

In the repository, **Settings**, **Environments**, create an environment named `rubygems` (it must match the value above). Add **required reviewers** so a person has to approve each release before the publish job runs. Use **Prevent self-review** only if you have at least two reviewers.

{: .note }
On GitHub Free, environments (and their reviewers) only work for **public** repositories. If the repository is private on a Free plan, the approval gate is ignored, so check the repository's visibility before relying on it.

### 4. Check the name is accepted

The name `messengerr` is currently free on RubyGems, but a different gem named `messenger` exists and RubyGems applies name-similarity checks that can only be tested by publishing. If the first push is rejected for the name, nothing is published and no version is used up. Choose another name then (it touches the gemspec, the CLI executable, the docs and the URLs).

## Releasing a version

1. **Pick the version** in `lib/messengerr/version.rb` ([semantic versioning](https://semver.org)). While the version is `0.x`, breaking changes may land in a minor release.
2. **Date the changelog.** In `CHANGELOG.md` the heading for the version must read `## X.Y.Z (YYYY-MM-DD)`. A heading that still says `unreleased` blocks the release.
3. **Check locally:**

   ```sh
   bundle exec rspec
   bundle exec rubocop
   bundle exec rake docs:check
   bundle exec rake release:check TAG=vX.Y.Z
   ```

4. **Look inside the gem.** It should hold only `lib/`, `exe/`, `README.md` and `LICENSE`:

   ```sh
   gem build messengerr.gemspec
   tar -xOf messengerr-X.Y.Z.gem data.tar.gz | tar -tz
   ```

5. **Merge to `main`** and wait for CI to pass on all of Ruby 3.2, 3.3 and 3.4.
6. **Tag the commit on `main` and push the tag.** The workflow refuses a tag whose commit is not on `main`. This is the step that publishes:

   ```sh
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```

7. **Approve.** The Release workflow runs `verify` (tag is on `main`, tag matches the version, changelog is dated, specs, lint, docs check), then waits for a reviewer on the `rubygems` environment, then publishes to RubyGems and creates a GitHub release from the changelog notes.
8. **Confirm.** Check the gem page on RubyGems, then install it in a clean directory:

   ```sh
   gem install messengerr -v X.Y.Z
   messengerr --version
   ```

Do not run `rake release` yourself unless you mean to publish: it tags and pushes the gem straight away. The workflow runs it for you.

## Rehearsal

Before the first real release, check the workflow with a tag that is meant to fail:

```sh
git tag v0.0.0-rehearsal
git push origin v0.0.0-rehearsal
```

The `verify` job should run and stop at "tag does not match the gem version", so `publish` never starts and nothing can reach RubyGems. Then delete the tag:

```sh
git push origin :refs/tags/v0.0.0-rehearsal
git tag -d v0.0.0-rehearsal
```

## Docs

The docs site is separate from the gem. It redeploys to GitHub Pages whenever `docs/**` changes on `main`, and needs no release.

## If something goes wrong

- **The workflow fails in `verify`.** Nothing was published. Fix the problem, then move the tag: delete it (`git tag -d vX.Y.Z` and `git push origin :refs/tags/vX.Y.Z`), commit the fix, and tag again.
- **The workflow fails after publishing.** Check RubyGems before retrying. If the version is there, do not publish it again: only the GitHub release is missing, and you can create it by hand.
- **A bad version was published.** Yank it so new installs skip it, then publish a fixed version:

  ```sh
  gem yank messengerr -v X.Y.Z
  ```

- **A credential or secret was published inside the gem.** Yank it, rotate the secret, and publish a clean version. Yanking does not remove copies people already downloaded.
