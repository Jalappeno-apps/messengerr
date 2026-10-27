---
title: CSV and templates
nav_order: 4
description: "How messengerr reads your CSV, the placeholder rules for message bodies and subjects, how contacts are validated, and what happens to repeated contacts."
---

# CSV and templates
{: .no_toc }

<details open markdown="block">
  <summary>On this page</summary>
  {: .text-delta }
1. TOC
{:toc}
</details>

## Placeholders

A placeholder is a column name in double braces: `{% raw %}{{name}}{% endraw %}`. Spaces just inside the braces are allowed (`{% raw %}{{ name }}{% endraw %}`).

- Names may contain letters, digits and underscores only. `{% raw %}{{first_name}}{% endraw %}` works. `{% raw %}{{first-name}}{% endraw %}` and `{% raw %}{{first name}}{% endraw %}` do not match the pattern.
- Anything left that still looks like `{% raw %}{{` or `}}{% endraw %}` after substitution makes the run abort with `unrenderable placeholder left in message: ...`. A malformed placeholder is never sent as literal text.
- Values are trimmed of leading and trailing whitespace.
- Substitution happens once. If a CSV value itself contains `{% raw %}{{x}}{% endraw %}`, it is inserted as-is and is not expanded.
- An empty cell for a placeholder is an error for that row (`column "plan" is empty for {% raw %}{{plan}}{% endraw %}`), caught at the preview.
- The subject (email) follows the same rules as the body.
- In an HTML message (`--html`) every substituted value is HTML-escaped, so CSV data cannot add markup. Messages can also come from a multi-line file. See [HTML and multi-line messages]({{ '/html-email.html' | relative_url }}).

## Placeholders only insert a value

A placeholder fills in one CSV column. There is no logic: no `if`, no loops, no filters, no expressions. This is deliberate, so the preview shows exactly the message each person gets.

Anything that is not a plain placeholder is left in the message, and the run aborts with `unrenderable placeholder left in message`. Nothing is evaluated, and nothing is sent:

| You write | What happens |
|---|---|
| `{% raw %}{{name}}{% endraw %}`, `{% raw %}{{ name }}{% endraw %}` | The value of the mapped column |
| `{% raw %}{{#if plan}}...{{/if}}{% endraw %}` | Aborts: conditionals are not supported |
| `{% raw %}{{ name | upcase }}{% endraw %}` | Aborts: filters are not supported |
| `{% raw %}{{ name + plan }}{% endraw %}`, `{% raw %}{{name ? "a" : "b"}}{% endraw %}` | Aborts: expressions are not supported |
| `{% raw %}{{> partial}}{% endraw %}` | Aborts: includes are not supported |

If different people need different wording, split them into separate CSVs and run messengerr once for each.

{: .note }
Extra braces around a valid placeholder are kept literally: `{% raw %}{{{name}}}{% endraw %}` is sent as `{Alice}`. There is no "unescaped" variant of a placeholder.

Because a literal `{% raw %}{{` or `}}{% endraw %}` in your text is treated as a placeholder, you cannot send those character pairs verbatim.

## The CSV file

- Local file path. `~` is expanded.
- First row is the header. Header names are what you map placeholders to.
- UTF-8, with or without a byte-order mark (BOM). Files exported from Excel with a BOM work. Other encodings (for example Latin-1) are rejected with a clear error.
- **Duplicate header names are rejected** (`CSV has duplicate headers: ...`) because a placeholder could not tell which column you meant.
- The whole file is read into memory. This is fine for typical lists, but see [Limitations]({{ '/limitations.html' | relative_url }}) for very large files.
- Row numbers in messages refer to the file's data rows with the header as row 1, so the first data row is row 2.

## Contact validation

| Method | Rule |
|---|---|
| `email` | Must match Ruby's standard email pattern and the domain must contain a dot. Surrounding whitespace is removed and the address is lowercased. |
| `sms` | Parsed as a phone number and normalised to E.164 (`+12025550123`). Numbers without a country code need a default country. |

For SMS numbers in local format, set the default country before running:

```sh
export MESSENGERR_DEFAULT_COUNTRY=US
```

Without it, a number that does not start with `+` and a country code is reported as `invalid phone number`.

Rows that fail validation are reported as defects (`empty value`, `invalid email address`, `invalid phone number`) and you choose to drop them or abort. See [Sending]({{ '/sending.html' | relative_url }}).

## Repeated contacts

Contacts are **not** de-duplicated. If the same address appears on three rows, three messages are sent. One row is one message. This is deliberate: you may genuinely want one message per row to the same person.

If you do not want that, remove duplicates from the CSV before sending. The preview shows the total number of messages, which makes an unexpectedly large list easy to spot.
