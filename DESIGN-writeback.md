# Write-Back Safety Model

**Invariant: the user's config is never corrupted.** Settings permission editing
goes through seven defenses. Implemented in `WriteGuard` (file safety) and
`SettingsSerializer` (content safety); orchestrated by `SettingsStore`.

| # | Defense | Where | Verified by |
|---|---------|-------|-------------|
| 1 | **Backup-first** — copy on-disk version to `~/.claude/backups/settings.json.{ISO8601}.bak` before any write; keep newest 20 | `WriteGuard.commit` / `backup` | `WriteGuardTests.testCommitWritesAndBacksUp` |
| 2 | **Atomic write** — write via `Data.write(options: .atomic)` (temp + rename); never a partial file. Symlinks resolved so the real target is written, not the link | `WriteGuard` | same |
| 3 | **Preserve-unknown** — mutate only `permissions.{allow,ask,deny}`; every other top-level key and every other `permissions` sub-key is carried through | `SettingsSerializer.apply` | `SettingsSerializerTests.testPreserveUnknownKeys` |
| 4 | **Validate-before-write** — reject empty rules; only commit if re-serialization yields valid JSON | `SettingsStore.save` | — |
| 5 | **Stale-guard** — re-read the file right before writing; if its hash differs from the loaded hash, abort (no clobber) and force reload | `WriteGuard.commit` | `WriteGuardTests.testStaleGuardRejects` |
| 6 | **Explicit save + discard** — no autosave; edits live in memory until the user clicks Save (⌘S). Discard reverts to the loaded snapshot | `SettingsStore` / `SettingsView` | — |
| 7 | **Rollback** — Restore writes the newest backup back (itself backup-first) | `WriteGuard.restoreLatest` | `WriteGuardTests.testRestoreLatest` |

## Serialization

`JSONSerialization` with `.prettyPrinted + .sortedKeys + .withoutEscapingSlashes`.
`.sortedKeys` makes output deterministic so repeated saves produce stable git diffs.
The first save may reorder keys once (alphabetical); subsequent saves are stable.

## Data flow

```
load (record hash)
  → edit form (in memory)
  → Save
    → validate
    → re-read file, compare hash   ── differs? ▶ abort + mark stale + reload
    → backup on-disk version
    → atomic write
    → update hash + snapshot
```

## Scope

All sections are editable, each routed through the same WriteGuard:

| Section | File | Store | Strategy |
|---------|------|-------|----------|
| Permissions / Env / Hooks | `settings.json` | `SettingsStore` (one shared instance) | dict mutate + sorted JSON; hooks/env rewritten only when changed |
| MCP servers | `~/.claude.json` | `MCPStore` | dict mutate + compact JSON; per-server unknown keys preserved |
| Skills / Agents / Commands | each `*.md` | `TextFileStore` | whole-file raw text — no frontmatter reserialization |

Cross-file safety notes:
- Skills/agents are often symlinked to an external repo; the editor shows a
  warning and still routes backups to `~/.claude/backups`.
- `~/.claude.json` is written by Claude Code at runtime — the stale-guard is the
  primary protection, and the UI warns about it.
- Backups are namespaced by a path hash, so the many same-named `SKILL.md`
  files never collide or cross-restore.
