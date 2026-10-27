---
title: Using with Claude
nav_order: 14
description: "Install the messengerr skill for Claude Code so Claude can prepare and dry-run a send for you. You always send."
---

# Using with Claude
{: .no_toc }

An optional skill that lets Claude Code prepare and preview a send. Claude never sends: you run the final command yourself.

<details open markdown="block">
  <summary>On this page</summary>
  {: .text-delta }
1. TOC
{:toc}
</details>

## Before you start

Install messengerr 0.2.0 or newer. The skill relies on its send flags and on the check that a real send needs a terminal.

```sh
gem install messengerr
messengerr --version
```

Set up your email or SMS provider yourself, in your own terminal. Claude never handles credentials.

```sh
messengerr credentials setup <name>
```

## Install the skill

### Option 1: plugin marketplace

This one updates through the marketplace. In Claude Code, run:

```
/plugin marketplace add Jalappeno-apps/messengerr_skill
```

Then install the `messengerr` plugin from the catalog.

### Option 2: copy the skill

This makes a personal skill available in every project.

```sh
git clone https://github.com/Jalappeno-apps/messengerr_skill
cp -r messengerr_skill/skills/messengerr ~/.claude/skills/
```

To share it with one project instead, copy it into `.claude/skills/` inside that repository.

Start a new Claude Code session afterwards.

## Use it

Ask for something like "send this newsletter to my CSV", or run `/messengerr`. Claude will:

1. Check the CLI and which integrations are configured.
2. Inspect your CSV (counts only, never contact values).
3. Help write the message, plain text or an HTML letterhead.
4. Dry-run it and show you the preview.
5. Give you the exact `messengerr send` command.

You paste that command into your own terminal, check the preview and type `y`. Afterwards, Claude can summarise the ledger for you.

## What Claude may and may not do

| May | May not |
|---|---|
| Run `messengerr --version`, `credentials list`, `integrations`, `send --help` | Run `messengerr send` without `--dry-run` |
| Check the CSV structure | Read, print or write credentials |
| Run a forced `--dry-run` preview | Run `credentials setup` or `delete` |
| Summarise a ledger, with addresses masked | Paste your contact list into the chat |
| Draft messages and letterheads | Use `--allow-non-interactive` |

A guard hook in the skill enforces this, and messengerr itself also refuses a real send outside an interactive terminal.

## Your responsibilities

You need consent from recipients and a working opt-out. The letterhead template does not add an unsubscribe link.

The skill's source is at [Jalappeno-apps/messengerr_skill](https://github.com/Jalappeno-apps/messengerr_skill).
