# Per-Machine Setup

The KB is per-machine; there is no built-in sync. Configure where it lives by
setting `$AGENTS_KB_DIR` per machine.

## Default home machine

Leave `$AGENTS_KB_DIR` unset; the KB resolves to `~/.knowledge/`. No action
needed.

## Restricted or sandboxed machine

When `$HOME` is read-only or otherwise unsuitable (locked-down work profile,
sandboxed runner), set `AGENTS_KB_DIR` to a writable path. Three places to set
it, in order of precedence:

1. Per-project `.claude/settings.json` `env` block — scopes to one repo.
2. Per-work-tree direnv `.envrc` — scopes to one checkout.
3. Global `~/.claude/settings.json` `env` block, or your shell rc — applies
   everywhere.

The `AGENTS_` prefix is the convention for env vars consumed by AI agents; it
parallels the `AGENTS.md` convention.

## Verifying

Always confirm the resolved path before relying on it:

```sh
bash ~/.claude/skills/knowledge-base/bin/kb where
```

The helper resolves the path with the same rule the skill uses, so they cannot
disagree.
