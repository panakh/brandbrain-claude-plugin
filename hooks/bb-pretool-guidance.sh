#!/usr/bin/env bash
#
# bb-pretool-guidance.sh
#
# PreToolUse hook for the brandbrain Claude Code plugin.
# Detects whether a Bash tool call is invoking the `bb` CLI; if so, emits a
# JSON object on stdout with `hookSpecificOutput.additionalContext` carrying
# the brandbrain pre-flight rules plus the full SKILL.md body. This guarantees
# the agent rereads the BrandBrain guidelines on EVERY `bb` call, even when
# the skill description did not trigger a fresh skill load.
#
# Contract (Claude Code hooks spec):
#   - Reads the tool payload as JSON on stdin.
#   - On a `bb` invocation, prints a JSON object on stdout:
#       {
#         "hookSpecificOutput": {
#           "hookEventName": "PreToolUse",
#           "permissionDecision": "allow",
#           "additionalContext": "<pre-flight + SKILL.md>"
#         }
#       }
#   - On any non-`bb` Bash call, prints nothing and exits 0 (no-op).
#   - On any internal error (missing jq, missing SKILL.md), still exits 0 so
#     the user's `bb` call is never blocked by a broken hook.
#
# Word-boundary match notes:
#   `bb`, `bb post`, `bb -h`, `/usr/local/bin/bb post`, and
#   `~/.local/bin/bb post --review` MUST match. `cbb`, `dbb foo`, `echo bb`
#   (where `bb` is an argument, not the verb) MUST NOT match.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
SKILL_PATH="${PLUGIN_ROOT}/skills/brandbrain/SKILL.md"

# Fail-soft: if jq is missing, do nothing rather than break the user's bb call.
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

# Read entire stdin payload, then extract the bash command. Tolerate an empty
# or malformed payload by treating it as a no-op.
payload="$(cat)"
if [[ -z "$payload" ]]; then
  exit 0
fi

command_str="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
if [[ -z "$command_str" ]]; then
  exit 0
fi

# Word-bounded match for `bb` as an executable name. We accept:
#   bb               -> bare command
#   bb <args>        -> bare command with args
#   /path/to/bb      -> absolute or relative path ending in /bb
#   /path/to/bb args -> ...with args
# We reject:
#   cbb, xbb, bbsomething (the `bb` is part of a larger name)
#   echo bb (where bb is an argument)
#
# Regex anchors at start of string; first token may be a path; the path's last
# segment must be exactly `bb`; followed by EOL or whitespace.
if ! [[ "$command_str" =~ ^[[:space:]]*([^[:space:]]*/)?bb([[:space:]]|$) ]]; then
  exit 0
fi

# Pre-flight prose. NO em-dashes; em-dash ban is the user's #1 banned token
# and the very rule we are documenting here.
preflight=$'BrandBrain skill rules, auto-injected by plugin hook on every `bb` invocation.\n\nPRE-FLIGHT for content/source-creating verbs (`bb post`, `bb source create`, `bb content *`, `bb publish`):\n1. Run `bb -h` cold each session, and `bb <verb> -h` if you have not yet read it this session. The CLI is the spec; do not guess flags.\n2. Discover user brand context BEFORE drafting. Run `bb -h` and look for verbs like `brand`, `me`, `config`, `prefs`. If one exists, run it and read the response BEFORE creating content. If NO such verb exists today, STOP and ask the user about brand voice, colour scheme, banned phrases, and target audience first; also tell the user this discovery verb is missing so it can be added.\n3. Apply user writing rules: NO em-dashes. NO AI-generated buzzwords (game-changer, leverage, streamline, delve, dive deep, in today\'s fast-paced world, unlock, harness, navigate the complexities, etc.). Brand voice must stay consistent across posts.\n4. After a `bb` call returns, quote any printed `<Key>: <url>` line VERBATIM. Never construct BrandBrain URLs from a contentId or sourceId; that path leads to invented routes such as `/review/<id>`.\n\nFull SKILL.md follows.\n---\n'

skill_body=""
if [[ -f "$SKILL_PATH" ]]; then
  skill_body="$(cat "$SKILL_PATH")"
fi

additional_context="${preflight}${skill_body}"

# Emit the hook output JSON. jq -n -R --arg builds the string field safely so
# embedded quotes, newlines, and backslashes are escaped per JSON rules.
jq -n \
  --arg ctx "$additional_context" \
  '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      additionalContext: $ctx
    }
  }'

exit 0
