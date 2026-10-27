---
title: messengerr
layout: home
nav_order: 1
nav_exclude: true
description: "Send templated email and SMS to a CSV contact list from your terminal: validated contacts, a preview before sending, and a record of every result."
---

<div class="hero">
  <span class="eyebrow">Command-line tool</span>
  <h1>Send templated messages to a list, safely.</h1>
  <p class="lede">Write one message with <code>{% raw %}{{placeholders}}{% endraw %}</code>, point messengerr at a CSV, and it validates the contacts, shows you exactly what will go out, sends through your provider, and keeps a record of every result.</p>
  <div class="actions">
    <a class="btn btn-primary" href="getting-started.html">Get started</a>
    <a class="btn" href="integrations.html">Integrations</a>
    <a class="btn" href="https://github.com/jalappeno-apps/messengerr">GitHub</a>
  </div>
  <div class="install"><span class="prompt">$</span><span>gem install messengerr</span></div>
</div>

## What you get
{: .section-title }

<div class="cards">
  <div class="card">
    <span class="icon">&#10003;</span>
    <h3>Preview before anything is sent</h3>
    <p>See the first rendered messages and the total count, then confirm. <code>--dry-run</code> stops there and sends nothing.</p>
  </div>
  <div class="card">
    <span class="icon">&#9776;</span>
    <h3>A record of every result</h3>
    <p>Each outcome is written to a ledger as it happens, so a crash or Ctrl-C never loses track of who was messaged.</p>
  </div>
  <div class="card">
    <span class="icon">&#8635;</span>
    <h3>Resume without duplicates</h3>
    <p>Pick up an interrupted run with <code>--resume</code>. Failures that might already have been delivered are flagged before you retry.</p>
  </div>
  <div class="card">
    <span class="icon">&#9881;</span>
    <h3>Pluggable providers</h3>
    <p>Postmark for email and ClickSend for SMS today. A small contract makes new integrations straightforward to add.</p>
  </div>
</div>

## How a send works
{: .section-title }

<ol class="steps">
  <li><strong>Configure an integration</strong><span>Store your provider's credentials once, verified live and encrypted at rest.</span></li>
  <li><strong>Write the message</strong><span>Use <code>{% raw %}{{column}}{% endraw %}</code> placeholders in the body and, for email, the subject.</span></li>
  <li><strong>Map your CSV</strong><span>Choose the column for each placeholder and the column that holds the address or number.</span></li>
  <li><strong>Review</strong><span>Bad contacts are listed by row. You drop them or abort to fix the file. Then you see a preview.</span></li>
  <li><strong>Send</strong><span>Messages go out in batches. Failures are listed with reasons, and you decide whether to retry.</span></li>
</ol>

## See it
{: .section-title }

<div class="terminal">
  <div class="bar"><i></i><i></i><i></i><b>messengerr send --dry-run</b></div>
<pre><span class="c"># a CSV with one bad address</span>
<span class="p">1 contact(s) have defects:</span>
  row 4: "not-an-email" — invalid email address
<span class="p">Drop these contacts and continue? (n = abort to fix) [y/n]</span> y

--- Preview (2 messages) ---
To: ann@example.com
Subject: Invoice for Ann
Body: Hi Ann, your Pro invoice is ready.
...
<span class="ok">Dry run — nothing sent. Ledger skipped.</span></pre>
</div>

New here? Follow [Getting started]({{ '/getting-started.html' | relative_url }}). Something broken? See [Troubleshooting]({{ '/troubleshooting.html' | relative_url }}). Know what to expect from the tool, including what it does not do yet, in [Limitations]({{ '/limitations.html' | relative_url }}).
