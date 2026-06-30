#!/usr/bin/env bash
# inbox.sh — portable helper for the TPC Disposable Inbox API (agent-friendly temp mail).
#
# Auth: a single scoped API key, shared by all your agents. Loaded from (first found):
#   $INBOX_API_KEY                              (env)
#   ~/.config/disposable-inbox/key.env          (file, mode 600, OUT of git: INBOX_API_KEY=...)
#
# Agent attribution: every mailbox records which agent created it. Set $AGENT_NAME
# (1-80 chars) so the dashboard can attribute your mailboxes; defaults to the shell
# user if unset. Override per-call with `new <ttl> <agentName>` / `custom <lp> <ttl> <agentName>`.
#
# Canonical API docs (source of truth):
#   https://temporary-inboxes.theportlandcompany.com/docs
#
# Usage:
#   inbox.sh new [ttlMinutes] [agent]    Create a random mailbox  -> prints MAILBOX_ID + MAILBOX_ADDR
#   inbox.sh custom <localpart> [ttl] [agent]  Create a custom-alias mailbox
#   inbox.sh addr <mailboxId>            Print the address for a mailbox
#   inbox.sh wait <mailboxId> [seconds]  Long-poll for the next inbound message (default 30)
#   inbox.sh code <mailboxId>            Print the latest extracted OTP / link value
#   inbox.sh msgs <mailboxId>            List messages (json)
#   inbox.sh msg  <messageId>            Full message + verification candidates (json)
#   inbox.sh keep <mailboxId>            Turn expiration OFF (never expires)
#   inbox.sh rm   <mailboxId>            Delete (expire) a mailbox
#   inbox.sh raw <METHOD> <path> [body]  Raw authenticated API call
set -euo pipefail

CFG="${INBOX_CONFIG:-$HOME/.config/disposable-inbox/key.env}"
[ -f "$CFG" ] && set -a && . "$CFG" && set +a
BASE="${INBOX_API_BASE:-https://tpc-disposable-inbox-api.the-portland-company.workers.dev}"
KEY="${INBOX_API_KEY:-}"
AGENT="${AGENT_NAME:-${USER:-agent}}"

if [ -z "$KEY" ]; then
  echo "inbox.sh: no API key. Set INBOX_API_KEY or create $CFG (see SKILL.md)." >&2
  exit 2
fi

api() { # METHOD PATH [BODY]
  local m="$1" p="$2" body="${3:-}"
  if [ -n "$body" ]; then
    curl -fsS -m 60 -X "$m" "$BASE$p" \
      -H "X-API-Key: $KEY" -H 'content-type: application/json' -d "$body"
  else
    curl -fsS -m 60 -X "$m" "$BASE$p" -H "X-API-Key: $KEY"
  fi
}
pyget() { python3 -c "import sys,json;d=json.load(sys.stdin);print(d$1)"; }

cmd="${1:-}"; shift || true
case "$cmd" in
  new)
    ttl="${1:-}"; agent="${2:-$AGENT}"
    body=$(python3 -c "import json,sys;print(json.dumps({'mode':'random','agentName':sys.argv[2],**({'ttlMinutes':int(sys.argv[1])} if len(sys.argv)>1 and sys.argv[1] else {})}))" "$ttl" "$agent")
    out=$(api POST /v1/mailboxes "$body")
    echo "MAILBOX_ID=$(echo "$out" | pyget "['id']")"
    echo "MAILBOX_ADDR=$(echo "$out" | pyget "['address']")"
    ;;
  custom)
    lp="${1:?localpart required}"; ttl="${2:-}"; agent="${3:-$AGENT}"
    body=$(python3 -c "import json,sys;print(json.dumps({'mode':'custom','localPart':sys.argv[1],'agentName':sys.argv[3],**({'ttlMinutes':int(sys.argv[2])} if len(sys.argv)>2 and sys.argv[2] else {})}))" "$lp" "$ttl" "$agent")
    out=$(api POST /v1/mailboxes "$body")
    echo "MAILBOX_ID=$(echo "$out" | pyget "['id']")"
    echo "MAILBOX_ADDR=$(echo "$out" | pyget "['address']")"
    ;;
  addr)  api GET "/v1/mailboxes/$1" | pyget "['address']" ;;
  wait)  api GET "/v1/mailboxes/$1/wait?timeoutSeconds=${2:-30}" ;;
  code)  api GET "/v1/mailboxes/$1/latest-verification" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('value','') if isinstance(d,dict) else '')" ;;
  msgs)  api GET "/v1/mailboxes/$1/messages" ;;
  msg)   api GET "/v1/messages/$1" ;;
  keep)  api PATCH "/v1/mailboxes/$1" '{"neverExpires":true}' ;;
  rm)    api DELETE "/v1/mailboxes/$1" ;;
  raw)   api "$1" "$2" "${3:-}" ;;
  *) sed -n '2,30p' "$0"; exit 1 ;;
esac
