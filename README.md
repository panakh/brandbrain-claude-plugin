# BrandBrain - Claude Code plugin

Post content to any BrandBrain-connected platform (LinkedIn, Instagram, X,
Threads, and more) from Claude Code through the `bb` CLI. Claude drafts and
decides; `bb` executes.

## Install

Two paths, same skill content.

**Via the `bb` CLI (if you already have `bb` v0.2+):**

```
bb skills install
```

**Via the Claude Code marketplace:**

```
claude plugin marketplace add https://github.com/panakh/brandbrain-claude-plugin
claude plugin install brandbrain@brandbrain-claude-plugin
```

The marketplace path does not ship the `bb` binary itself. The skill's
`SKILL.md` contains an inline bootstrap protocol that Claude follows on first
use: detect target triple, download the pinned `bb` release from this repo's
GitHub releases, verify the SHA-256 checksum, extract to `~/.local/bin/bb`,
and strip the macOS quarantine attribute. No separate installer is required.

## Prerequisites

- A BrandBrain account. Sign in with `bb auth login` after the bootstrap
  puts `bb` on your `PATH`.
- `curl` and `tar` on macOS/Linux, or PowerShell on Windows (standard).

## What this plugin does

It installs a single self-describing skill, `brandbrain`, into Claude Code's
skill discovery path. The skill does not enumerate platforms, formats, or
flags statically - it teaches Claude to read `bb -h` and `bb <verb> -h` at
runtime and treat the help output as the authoritative tool catalog. Any new
`bb` verb or capability is picked up automatically without a plugin update.

Learn more at <https://brandbrain.app>.

## License

See `LICENSE`.
