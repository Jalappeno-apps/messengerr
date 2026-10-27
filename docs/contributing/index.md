---
title: Contributing
nav_order: 13
has_children: true
permalink: /contributing/
description: "Contribute to messengerr: set up the project, read the architecture, and learn how integrations, tests and releases work."
---

# Contributing
{: .no_toc }

Bug reports and pull requests are welcome at [github.com/jalappeno-apps/messengerr](https://github.com/jalappeno-apps/messengerr).

New to the code? Read in this order:

1. [Architecture](architecture.html): how a send flows and what the main classes do.
2. [Writing an integration](writing-an-integration.html): the checklist for adding a built-in provider.
3. [Testing](testing.html): the fast suite, the helpers, and how to check a spec really tests the fix.
4. [Style](style.html) and [Releasing](releasing.html).

## Set up

```sh
git clone https://github.com/jalappeno-apps/messengerr
cd messengerr
bundle install
bundle exec rspec
bundle exec rubocop
```

The suite uses WebMock and temporary directories. It makes no real network calls and never touches your real `~/.config/messengerr`.

## The principle

messengerr sends real messages to real people, and a mistake cannot be taken back. So the code is built around a few promises: nothing is sent before a preview and confirmation, every recipient gets exactly one result, results are recorded as they happen, and failures that might have been delivered are never retried silently. [STYLE.md](https://github.com/jalappeno-apps/messengerr/blob/main/STYLE.md) lists them as invariants. A change that weakens one needs a deliberate decision, a spec, and a docs update.
