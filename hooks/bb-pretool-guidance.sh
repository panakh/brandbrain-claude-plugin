#!/usr/bin/env bash
#
# bb-pretool-guidance.sh
#
# PreToolUse hook for the brandbrain Claude Code plugin.
# Detects whether a Bash tool call is invoking the `bb` CLI; if so, emits a
# JSON object on stdout with `hookSpecificOutput.additionalContext` carrying
# the brandbrain pre-flight rules. This guarantees the agent rereads the
# BrandBrain pre-flight checklist on EVERY `bb` call, even when the skill
# description did not trigger a fresh skill load. The full SKILL.md body is
# loaded separately via the plugin's skill description-trigger and is NOT
# re-injected here (re-inlining it on every `bb` call exceeded the harness
# tool-result cap and triggered persisted-output truncation banners).
#
# Contract (Claude Code hooks spec):
#   - Reads the tool payload as JSON on stdin.
#   - On a `bb` invocation, prints a JSON object on stdout:
#       {
#         "hookSpecificOutput": {
#           "hookEventName": "PreToolUse",
#           "permissionDecision": "allow",
#           "additionalContext": "<pre-flight prose>"
#         }
#       }
#   - On any non-`bb` Bash call, prints nothing and exits 0 (no-op).
#   - On any internal error (missing jq), still exits 0 so the user's `bb`
#     call is never blocked by a broken hook.
#
# Word-boundary match notes:
#   `bb`, `bb content create`, `bb -h`, `/usr/local/bin/bb content create`, and
#   `~/.local/bin/bb content approve --id=...` MUST match. `cbb`, `dbb foo`, `echo bb`
#   (where `bb` is an argument, not the verb) MUST NOT match.

set -euo pipefail

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
preflight=$'BrandBrain skill rules, auto-injected by plugin hook on every `bb` invocation.\n\nPRE-FLIGHT for any `bb` verb that touches content, whether to create, mutate, or review (`bb content create`, `bb content edit`, `bb content get`, `bb content list`, `bb source create`, `bb media *`, `bb products create|update|delete|image-upload`, `bb products list`, `bb products get`, `bb products research save|clear|read`):\n1. Run `bb -h` cold each session, and `bb <verb> -h` if you have not yet read it this session. The CLI is the spec; do not guess flags. The brand-context preflight checklist below is also baked into `bb content create -h` itself.\n2. Read user brand context BEFORE drafting OR reviewing:\n   - `bb prefs list`              active user preferences (brand-profile memory: voice, tone, banned phrases, recurring instructions).\n   - `bb defaults get`            workspace content defaults (brand identity, colour palette, default tone, namespace-keyed fields).\n   - `bb guidelines list`         available BrandBrain cloud guidelines; then `bb guidelines read <slug>` for the full body of any guideline relevant to the task.\n   - `bb products list`           list the user\'s products; `bb products get <id>` for full detail; `bb products research read <id>` if the post or review references the product.\n3. Apply user writing rules: NO em-dashes. NO AI-generated buzzwords (game-changer, leverage, streamline, delve, dive deep, in today\'s fast-paced world, unlock, harness, navigate the complexities, etc.). Brand voice must stay consistent across posts.\n4. After a `bb` call returns, quote any printed `<Key>: <url>` line VERBATIM. Never construct BrandBrain URLs from a contentId or sourceId; that path leads to invented routes such as `/review/<id>`.\n5. RESTful CLI shape (v0.3.17+): primary IDs are POSITIONAL on every single-resource verb, matching `gh / kubectl / stripe / docker`. Use `bb content get <id>` / `bb content edit <id> --status approved` / `bb content approve <id>` / `bb content reject <id> --reason "..."` / `bb content schedule <id> --at <iso>` / `bb content publish <id>` / `bb content delete <id>` / `bb products {get,update,delete,image-upload} <id>` / `bb products research {save,read,clear} <id>` / `bb prefs {update,delete,restore} <id>` / `bb guidelines read <slug>` / `bb media attach <content-id>`. The legacy `--id <id>` flag still parses as a hidden back-compat alias on every verb that takes an id, but the positional form is the documented one. The legacy `bb post` verb was removed in 0.3 and never appears anywhere in scripts.\n6. JSON output: every verb that has `--format-json` also accepts the shorter `--json` alias. Both produce identical output. Prefer `--json` going forward, matching every other modern CLI.\n'

additional_context="${preflight}"

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
