---
name: brandbrain
description: Post content to LinkedIn, Instagram, X, Threads, and other platforms, and read or edit the BrandBrain product catalog and per-product market research (brand product memory) — all via the `bb` CLI. Claude drafts and decides; `bb` executes. Use whenever the user wants to publish/draft/schedule/queue a social post, thread, or carousel; list, get, create, update, or delete products; save, read, or clear market research on a product; or upload a product image.
---

# brandbrain

Thin wrapper around the `bb` CLI, BrandBrain's authenticated agent surface. You are the brain; `bb` is the hands. Read help text at runtime; do not rely on memory.

## Pre-flight (every `bb` invocation)

Before any `bb` verb that touches content, whether to create, mutate, or review (`bb content create`, `bb content edit`, `bb content get`, `bb content list`, `bb source create`, `bb media *`, `bb products create|update|delete|image-upload`, `bb products list`, `bb products get`, `bb products research save|clear|read`):

1. Read the CLI as the spec. Run `bb -h` cold each session, and `bb <verb> -h` for any verb you have not used yet this session. Do not guess flags. The brand-context preflight checklist is also baked into `bb content create -h` itself, so reading that help text refreshes the rules.
2. Read the user's brand context BEFORE drafting or reviewing:
   - `bb prefs list` reads active user preferences (brand-profile memory: voice, tone, banned phrases, recurring instructions).
   - `bb defaults get` reads workspace content defaults (brand identity, colour palette, default tone, namespace-keyed fields).
   - `bb guidelines list` shows available BrandBrain cloud guidelines for the signed-in workspace; then `bb guidelines read <name>` fetches the full body of any guideline relevant to the task.
   - `bb products list` lists the user's BrandBrain products; `bb products get <id>` returns full product detail (description, category, website, image) and any saved `marketResearch`. Read product context whenever a post promotes or references a specific product, and read `bb products research read <id>` if the post should lean on prior market research.
3. Apply user writing rules. NO em-dashes. NO AI-generated buzzwords (game-changer, leverage, streamline, delve, dive deep, in today's fast-paced world, unlock, harness, navigate the complexities, and the like). Keep the brand voice consistent across posts.
4. When a `bb` call returns, quote any printed `<Key>: <url>` line verbatim. Never build a BrandBrain URL from a contentId or sourceId yourself; that path leads to invented routes such as `/review/<id>`.

A PreToolUse plugin hook re-injects this skill's body on every `bb` Bash call, so this rule survives even when the skill description did not retrigger a fresh skill load.

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

## Installing BrandBrain Desktop

If the user asks to install BrandBrain Desktop (the macOS app), run:

```bash
curl -fsSL https://brandbrain.app/install.sh | bash
```

That single command installs `BrandBrain.app` to `/Applications/`, clears macOS quarantine so Gatekeeper allows first launch, and symlinks the app-bundled `bb` CLI into `~/.local/bin/bb`. Idempotent — safe to re-run as the update path. Launch with `open -a BrandBrain` once it finishes.

Linux and Windows are not supported by this installer in the current release; on those hosts, point the user at <https://brandbrain.app> for manual download options.

## Auth

Before any `bb` verb that talks to BrandBrain, preflight with `bb auth status`. If it reports `Source: none` or exits with code 2, ask the user to run `bb auth login` (opens a browser - only the user can complete it) and retry. If a later command returns a 401 / "not authenticated" / "token expired" error, re-run `bb auth status`; if the source shifted to `none` or the token expired, ask the user to re-login and retry the failed command after they confirm.

## Discovery Protocol

The CLI IS the tool catalog. Read help text every session:

1. `bb -h` - lists every top-level verb. Read it cold at the start of a session.
2. `bb <verb> -h` / `bb <verb> <sub> -h` - authoritative spec: purpose, when to use, parameters, exit codes, examples. Read before the first call each session. Do not guess flags.

## Usage

BrandBrain separates provenance (`Source`) from the post body (`Content`). Every `bb content create` call requires a Source reference AND a content body reference.

`bb content create` is the unified content-creation verb (replaces the legacy `bb post`, which was hard-removed in 0.3 - never released). It DEFAULTS to a draft (lands in the review queue). Use the dispatch flags for one-shot create-and-do-more behaviour.

- Two-verb flow (existing Source): `bb source create --type <t> --url <url>` -> `bb content create --platform <slug> --format <format> --source-id <id> --content <ref>`
- One-shot URL shortcut (inline Source creation): `bb content create --platform <slug> --format <format> --new-source-url <url> --new-source-type <youtube|tiktok|reel|link> --content <ref>`
- `--source-id` and `--new-source-url` are mutually exclusive. For research/news/insight/text Sources, always use `bb source create` first.
- Default (no `--publish`, no `--schedule-at`): draft only. Lands in BrandBrain's review queue. Approve later via `bb content approve <id>` or the BrandBrain web UI.
- One-shot publish: add `--publish` (chains create + approve + publish). Mutually exclusive with `--schedule-at`. Only works for formats whose dispatch is `publish_on_create`.
- Schedule: add `--schedule-at <iso-timestamp>` (chains create + approve with `scheduledAt`). Mutually exclusive with `--publish`.
- Pick a specific account: add `--account <id>`.
- Carousel image generation: add `--generate-images`. Hard-rejects with exit code 8 if any slide is missing `imagePrompt`. Re-read brand context (prefs + defaults + format guideline), resupply imagePrompts, retry.

State-transition controllers (act on EXISTING Content records by id; v0.3.17+ takes the id as a positional, matching `gh / kubectl / stripe`. The legacy `--id <id>` flag still parses as a back-compat alias):

- `bb content approve <id>` move pending_review -> approved.
- `bb content reject <id> [--reason=<s>]` move to rejected with optional reason.
- `bb content schedule <id> --at=<iso>` set scheduledAt on an approved record.
- `bb content publish <id>` push an approved record to the platform.

CRUD: `bb content get <id>` / `bb content edit <id> [...]` / `bb content delete <id>` / `bb content list`. Every verb that has `--format-json` also accepts the shorter `--json` alias.

Exact flag names come from `bb content create -h`, `bb content approve -h`, etc., and `bb source create -h`; treat the above as a mnemonic, not a contract. When `bb` returns non-zero, read stderr and follow the exit-code guidance from the verb's help.

## Products and market research

`bb products` manages the user's BrandBrain product catalog. Each product has metadata (name, description, category, website, image) and an optional `marketResearch` markdown blob — agent-curated research saved against the product. Read `bb products -h` and `bb products <sub> -h` for exact flags; the list below is a mnemonic, not a contract.

- `bb products list` — list all of the user's products
- `bb products get <id>` — full product detail including any saved market research
- `bb products create --name "..." [--description "..."] [--category "..."] [--website-url "..."] [--image-url "..."]` — create a new product
- `bb products update <id> [--name "..."] [--description "..."] [--category "..."] [--website-url "..."] [--image-url "..."]` — patch any subset of fields
- `bb products delete <id>` — delete a product
- `bb products image-upload <id> --file <path>` — upload a product image (multipart)
- `bb products research save <id> --from-file <path> | --text "..."` — save (overwrite) the product's market research markdown
- `bb products research read <id>` — read the saved market research
- `bb products research clear <id>` — clear the saved market research

There is no `bb products sync` verb. To "sync" a product from its website, the agent reads the site locally (WebFetch or browser), summarises into a fresh description, then calls `bb products update <id> --description "..."`. Same pattern if the agent needs to refresh the image — fetch locally, then `bb products image-upload`.

Examples:
- Edit the user's BrandBrain product description: `bb products update prod_abc --description "..."`
- Save market research to a product: `bb products research save prod_abc --from-file /tmp/research.md`
- Read existing market research before drafting a post that references the product: `bb products research read prod_abc`

When the response includes a `urls` object, quote `<Key>: <url>` lines verbatim - same rule as `bb content create`. Do not construct BrandBrain product URLs from a product id yourself.

## URLs

After a successful `bb` command, the API may return a `urls` object alongside the JSON payload (e.g. `urls.review`, `urls.edit`, `urls.live`, `urls.published_view`, `urls.view`). `bb` prints these as `<Key>: <url>` lines on stdout. Quote them VERBATIM when telling the user where to look — never construct a BrandBrain URL from a contentId or sourceId yourself. URL formats live in the API; treating them as memory leads to invented routes (e.g. `/review/<id>` does not exist).

If a particular `urls.<key>` is missing from the response, that surface either has no canonical URL yet or the older API version did not return it — say so honestly rather than guessing.

Static app pages (no resource id needed) — safe to reference directly:

- <https://www.brandbrain.app/content> — content drafts/review/published list
- <https://www.brandbrain.app/discovery/sources> — sources list
- <https://www.brandbrain.app/schedule> — scheduled posts
- <https://www.brandbrain.app/billing> — billing and wallet
- <https://www.brandbrain.app/settings/connections> — social account connections
- <https://www.brandbrain.app/settings/api-tokens> — agent API tokens

## When not to use

Direct the user to <https://www.brandbrain.app> for billing, connection management, approving content already in review, or editing scheduled posts. Those are web-UI tasks, not `bb` tasks.
