# Disposable Inbox — Agent Skill

A portable [agent skill](https://docs.claude.com/en/docs/claude-code/skills) that
teaches AI agents to use the **TPC Disposable Inbox** — a hosted temp-mail service
built for automation. Agents get a real, disposable email address they can read
programmatically to capture sign-up confirmations, OTP codes, magic links, and
password-reset links during testing and account automation.

## The model

One human registers **one account** and mints **one scoped API key**. From then on,
any number of agents share that key (`X-API-Key`) to create throwaway mailboxes and
read what arrives — no per-task account setup.

- **Service / dashboard:** https://temporary-inboxes.theportlandcompany.com
- **API base URL:** `https://tpc-disposable-inbox-api.the-portland-company.workers.dev`
- **API documentation (source of truth):** https://temporary-inboxes.theportlandcompany.com/docs

## Install

Copy this directory into your agent's skills folder (e.g. for Claude Code:
`~/.claude/skills/disposable-inbox/`), or clone it:

```bash
git clone https://github.com/The-Portland-Company/disposable-inbox-skill.git \
  ~/.claude/skills/disposable-inbox
chmod +x ~/.claude/skills/disposable-inbox/scripts/inbox.sh
```

Then do the one-time setup in [`SKILL.md`](./SKILL.md) (register an account, mint a
key, save it to `~/.config/disposable-inbox/key.env`).

## Quick start

```bash
eval "$(scripts/inbox.sh new)"        # create a mailbox -> MAILBOX_ID, MAILBOX_ADDR
# ...use $MAILBOX_ADDR to sign up / request a code...
scripts/inbox.sh wait "$MAILBOX_ID" 45
scripts/inbox.sh code "$MAILBOX_ID"   # the extracted OTP / link
```

See [`SKILL.md`](./SKILL.md) for the full workflow, and the
[API docs](https://temporary-inboxes.theportlandcompany.com/docs) for the complete
endpoint reference.

## Etiquette

Shared infrastructure. Use it only for legitimate testing and automation you are
authorized to run — not to evade abuse controls on third-party services.

## License

MIT — see [LICENSE](./LICENSE).
