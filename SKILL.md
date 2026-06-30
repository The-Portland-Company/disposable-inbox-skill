---
name: disposable-inbox
description: >-
  Get a real, disposable email address that an AI agent can read programmatically —
  to receive sign-up confirmations, OTP codes, magic links, and password-reset links
  while testing or automating account flows. Use when a task needs an email address
  to capture a verification code or link. Teaches the one-time human setup (register
  one account, mint one API key) and the agent runtime loop (create mailbox → wait →
  extract code) against the TPC Disposable Inbox API.
---

# Disposable Inbox (for AI agents)

A hosted temp-mail service built for automation: a catch-all domain, an HTTP API,
and built-in OTP / magic-link / reset-link extraction. One human registers **one
account** and mints **one API key**; from then on any number of agents share that
key to spin up throwaway mailboxes and read what arrives.

**Source of truth for the API:** https://temporary-inboxes.theportlandcompany.com/docs
Always defer to that page for the authoritative, current endpoint list and field
shapes — this skill summarizes it but the docs page is canonical.

- **API base URL:** `https://tpc-disposable-inbox-api.the-portland-company.workers.dev`
- **Dashboard / docs:** https://temporary-inboxes.theportlandcompany.com
- **Auth for agents:** `X-API-Key: <secret>` header (scoped key, created once)

---

## One-time human setup (do this once, not per task)

An agent cannot bootstrap its own account — a human registers it once, because
mailbox creation is gated behind a confirmed email identity.

1. Register an account at https://temporary-inboxes.theportlandcompany.com/auth/register
   and confirm the email (mailbox + API-key creation are blocked until confirmed).
2. Sign in, open the dashboard, and create a **scoped API key** (the key icon in the
   top toolbar). The **name you give the key is the agent name** — it is stamped onto
   every mailbox the key creates and shown in the dashboard (you can't override it per
   request, so it's trustworthy). Name the key per agent for distinct attribution.
   Copy the secret — it is shown only once.
3. Store the secret where your agents can read it, **outside any git repo**, e.g.:

   ```bash
   mkdir -p ~/.config/disposable-inbox
   printf 'INBOX_API_KEY=%s\n' "<paste-secret>" > ~/.config/disposable-inbox/key.env
   chmod 600 ~/.config/disposable-inbox/key.env
   ```

All agents on the machine now share that single account's key. Never print the key
or commit it.

> Prefer the API for key creation? With the account's Supabase JWT:
> `curl -X POST "$BASE/v1/api-keys" -H "Authorization: Bearer <jwt>" -H 'content-type: application/json' -d '{"label":"agents","scopes":["mailboxes:read","mailboxes:write","messages:read"]}'`
> The response's `secret` is the `X-API-Key` value.

---

## Agent runtime loop (every task that needs an email)

Use the bundled helper `scripts/inbox.sh` (it loads the key from
`~/.config/disposable-inbox/key.env` or `$INBOX_API_KEY`). Mailboxes are attributed
to your API key's name automatically — nothing to set per call:

```bash
# 1. Create a mailbox (random local part). Captures the id + address.
eval "$(scripts/inbox.sh new)"      # sets MAILBOX_ID and MAILBOX_ADDR
echo "$MAILBOX_ADDR"                 # use this address in your signup/test flow

# 2. ...trigger the email (sign up / request the code) using $MAILBOX_ADDR...

# 3. Block until the next message arrives (long-poll, up to N seconds)
scripts/inbox.sh wait "$MAILBOX_ID" 45

# 4. Extract the OTP / confirmation link
scripts/inbox.sh code "$MAILBOX_ID"  # prints the highest-confidence code or link
```

Other helper commands: `addr <id>`, `msgs <id>` (list), `msg <messageId>` (full
body + verification candidates), `custom <localpart> [ttlMinutes]`, `keep <id>`
(never-expire), `rm <id>` (delete). Run `scripts/inbox.sh` with no args for usage.

### Doing it with raw curl instead

```bash
BASE=https://tpc-disposable-inbox-api.the-portland-company.workers.dev
KEY=$INBOX_API_KEY

# create (agent name comes from the key label, no need to send it)
curl -s -X POST "$BASE/v1/mailboxes" -H "X-API-Key: $KEY" \
  -H 'content-type: application/json' \
  -d '{"mode":"random","ttlMinutes":60}'
# wait (returns 204 if nothing arrived in the window)
curl -s "$BASE/v1/mailboxes/<id>/wait?timeoutSeconds=30" -H "X-API-Key: $KEY"
# grab the extracted code/link
curl -s "$BASE/v1/mailboxes/<id>/latest-verification" -H "X-API-Key: $KEY"
```

---

## Conventions & limits

- **Agent name (automatic):** the creating agent shown in the dashboard (with the
  exact creation time) is your **API key's label** — stamped server-side, so it's
  trustworthy and can't be spoofed in the request body. Set it by naming the key.
- **Custom addresses:** `{"mode":"custom","localPart":"my-alias"}` — 3–40 chars,
  `[a-z0-9._-]`. If the address is held by another active account you get **409**;
  if it was yours/expired it is recycled. The domain is fixed (catch-all).
- **TTL:** `ttlMinutes` 5 min – 1 year, or `{"neverExpires":true}`. Max **10 active
  mailboxes** per account — let them expire or delete them when done.
- **Reading mail:** messages expose `textBody`, `htmlBody`, attachments, and
  `verification_candidates` (typed `otp` / `magic_link` / `reset_link` / `cta_link`
  with confidence). Prefer `latest-verification` for a one-shot grab.
- **Replies:** `POST /v1/messages/:id/reply` sends from the mailbox identity.
- **Etiquette:** this is shared infrastructure. Use it only for legitimate testing
  and automation you are authorized to run; do not use it to evade abuse controls
  on third-party services.

See the canonical API docs for the complete reference:
**https://temporary-inboxes.theportlandcompany.com/docs**
