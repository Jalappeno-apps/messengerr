---
title: HTML and multi-line messages
nav_order: 5
description: "Send an HTML email or a multi-line message from a file with messengerr: --html and --message-file, how values are escaped, and what is not supported."
---

# HTML and multi-line messages
{: .no_toc }

By default `messengerr send` asks for a one-line plain-text message. For anything longer, or for HTML email, put the message in a file.

<details open markdown="block">
  <summary>On this page</summary>
  {: .text-delta }
1. TOC
{:toc}
</details>

## Two flags

| Flag | Message is | Works for |
|---|---|---|
| `--message-file FILE` | Multi-line **plain text** | Email and SMS |
| `--html FILE` | An **HTML** email | Email only, and only integrations that can send HTML (Postmark can) |

Use one or the other, not both. The wizard then skips the "Message" prompt and reads the file. Everything else is the same: the subject is still asked (email), and `{% raw %}{{placeholders}}{% endraw %}` in the file are mapped to CSV columns exactly as they are in a typed message. See [Sending]({{ '/sending.html' | relative_url }}).

```sh
messengerr send --message-file letter.txt
messengerr send --html letterhead.html --dry-run
```

The file must be UTF-8 (a byte-order mark is fine). Line endings are normalised to `\n` and trailing whitespace at the end of the file is removed. A missing, empty or non-UTF-8 file stops the command before any prompt.

## One format per send

An HTML send is **HTML only**. messengerr does not also send a plain-text version, and it does not generate one from your HTML. Some mail clients and spam filters prefer a message with a text part, so for important mail you may want to check how it lands.

## Previewing HTML

The terminal preview does not print markup. It shows the recipient, the subject and the size:

```text
To: ann@example.com
Subject: A note from us
Body: HTML, 2712 characters
HTML preview of the first message: /path/to/messengerr-preview.html
```

Open that file in a browser to see exactly what the **first** recipient will get. It is rewritten on every run, including `--dry-run`, and holds only the rendered message (mode `0600`).

For a multi-line text message, the preview prints the lines indented under `Body:`.

## Placeholders are escaped in HTML

When you use `--html`, every value substituted from the CSV is **HTML-escaped**. A name such as `Tom & <b>Jerry</b>` appears as that literal text, and cannot add markup or break your layout. Your template's own HTML is trusted and left as you wrote it. The subject is plain text and is never escaped.

{: .warning }
Escaping protects against markup coming from the CSV. It does not check URLs. If you put a placeholder inside an `href` or `src`, make sure the values in that column are links you trust.

## A minimal template

Email clients ignore most modern CSS. The reliable recipe is table layout and inline styles, no external stylesheets and no scripts.

```html
<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"></head>
<body style="margin:0; background:#f4f4f4;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
    <tr><td align="center" style="padding:24px 12px;">
      <table role="presentation" width="600" cellpadding="0" cellspacing="0"
             style="width:100%; max-width:600px; background:#ffffff;">
        <tr><td style="background:#1f3a5f; padding:24px 32px; font:bold 24px Arial,sans-serif; color:#ffffff;">
          Your company
        </td></tr>
        <tr><td style="padding:32px; font:16px/26px Georgia,serif; color:#222222;">
          <p style="margin:0 0 16px 0;">Hi {% raw %}{{name}}{% endraw %},</p>
          <p style="margin:0;">Your message here.</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>
```

A few rules:

- Any `{% raw %}{{{% endraw %}` or `{% raw %}}}{% endraw %}` in the file is treated as a placeholder. Avoid them in CSS and scripts, or the run aborts with `unrenderable placeholder left in message`.
- Use a logo as text, or an image hosted at a public `https://` address. Images pasted into the file as data URIs are blocked by many clients.
- Test with your own addresses first.

## Not supported

Attachments, inline images, a separate plain-text part, CC/BCC and reply-to. See [Limitations]({{ '/limitations.html' | relative_url }}).
