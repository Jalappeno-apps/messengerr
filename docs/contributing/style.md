---
title: Style
parent: Contributing
nav_order: 5
description: "Where messengerr documents its code conventions and invariants, and how style is enforced with RuboCop."
---

# Style
{: .no_toc }

The conventions the codebase follows, and the invariants a change must not break, live in [`STYLE.md`](https://github.com/jalappeno-apps/messengerr/blob/main/STYLE.md) in the repository root. It is the single source for file layout, value objects, the integration contract, error handling, the CLI shape, how to write specs, and where the code is not yet consistent, so it is not duplicated here.

Code style is enforced by RuboCop (`rubocop-rails-omakase`): `bundle exec rubocop`. Match the surrounding code, and copy the shape of the closest existing file before inventing a new one.
