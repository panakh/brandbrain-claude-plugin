---
name: brandbrain
description: Post content to LinkedIn, Instagram, X, Threads, and other platforms using the `bb` CLI. Claude drafts and decides; `bb` executes. Use whenever the user wants to publish, draft, schedule, or queue a social post, thread, or carousel.
---

# brandbrain

Thin wrapper around the `bb` CLI, BrandBrain's authenticated agent surface. You are the brain; `bb` is the hands. Read help text at runtime; do not rely on memory.

## Bootstrap

If `bb --version` fails with "command not found", install it inline. Run each step yourself - there is no helper script.

1. Detect the target triple. Run `uname -s` and `uname -m`. Map: `Darwin/arm64` → `aarch64-apple-darwin`, `Darwin/x86_64` → `x86_64-apple-darwin`, `Linux/x86_64` → `x86_64-unknown-linux-gnu`, `Linux/aarch64` → `aarch64-unknown-linux-gnu`. On Windows use PowerShell `[System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture` and map to `x86_64-pc-windows-msvc` or `aarch64-pc-windows-msvc`.
2. Construct the URL: `https://github.com/panakh/brandbrain-claude-plugin/releases/latest/download/bb-<target>.tar.gz` (POSIX) or `bb-<target>.zip` (Windows).
3. Download to a temp path with `curl -fsSL -o /tmp/bb.tar.gz <url>` (POSIX) or `Invoke-WebRequest` (Windows).
4. Verify integrity. Fetch `SHA256SUMS.txt` from the same release, compute `shasum -a 256 /tmp/bb.tar.gz`, compare against the matching row. If they differ, delete the archive and stop - tell the user verification failed. This plugin embeds no hash itself; GitHub HTTPS + the release-scoped checksums file are the trust boundary. (Rationale: embedding a hash in SKILL.md would force a plugin bump on every `bb` release; the release's own `SHA256SUMS.txt` is already signed-to-tag.)
5. Extract and install. POSIX: `mkdir -p ~/.local/bin && tar -xzf /tmp/bb.tar.gz -C /tmp && install -m 0755 /tmp/bb ~/.local/bin/bb`. Windows: `Expand-Archive` into `$env:USERPROFILE\.bb\bin\`.
6. macOS only: `xattr -d com.apple.quarantine ~/.local/bin/bb 2>/dev/null || true` to clear Gatekeeper.
7. If `~/.local/bin` (POSIX) or `%USERPROFILE%\.bb\bin` (Windows) is not on `PATH`, print the exact one-liner the user should add to their shell profile and stop until they confirm.
8. Verify: `bb --version`. If it prints, bootstrap is done. Otherwise surface the error.

Runs once per machine. Subsequent sessions skip straight to the Discovery Protocol once `bb --version` succeeds.

## Auth

Before any `bb` verb that talks to BrandBrain, preflight with `bb auth status`. If it reports `Source: none` or exits with code 2, ask the user to run `bb auth login` (opens a browser - only the user can complete it) and retry. If a later command returns a 401 / "not authenticated" / "token expired" error, re-run `bb auth status`; if the source shifted to `none` or the token expired, ask the user to re-login and retry the failed command after they confirm.

## Discovery Protocol

The CLI IS the tool catalog. Read help text every session:

1. `bb -h` - lists every top-level verb. Read it cold at the start of a session.
2. `bb <verb> -h` / `bb <verb> <sub> -h` - authoritative spec: purpose, when to use, parameters, exit codes, examples. Read before the first call each session. Do not guess flags.

## Usage

BrandBrain separates provenance (`Source`) from the post body (`Content`). Every `bb post` call requires a Source reference AND a content body reference.

- Two-verb flow (existing Source): `bb source create --type <t> --url <url>` -> `bb post --platform <slug> --format <format> --source-id <id> --content <ref>`
- One-shot URL shortcut (inline Source creation): `bb post --platform <slug> --format <format> --new-source-url <url> --new-source-type <youtube|tiktok|reel|link> --content <ref>`
- `--source-id` and `--new-source-url` are mutually exclusive. For research/news/insight/text Sources, always use `bb source create` first.
- Schedule: add `--schedule-at <iso-timestamp>`
- Queue for review (skip status PUT): add `--review`
- Pick a specific account: add `--account <id>`

Exact flag names come from `bb post -h` and `bb source create -h`; treat the above as a mnemonic, not a contract. When `bb` returns non-zero, read stderr and follow the exit-code guidance from the verb's help.

## When not to use

Direct the user to <https://www.brandbrain.app> for billing, connection management, approving content already in review, or editing scheduled posts. Those are web-UI tasks, not `bb` tasks.
