# Persistent Quality Notes

Informational notes from quality reviews -- architectural debt, deferred design decisions, known limitations -- are persisted to the project's knowledge base entry rather than to a file inside the repo. Two reasons:

1. **No accidental commits.** A `QUALITY.md` at the repo root has a habit of getting staged with unrelated changes. The KB lives outside the repo, so this can't happen.
2. **Reuses an existing convention.** The `knowledge-base` skill already manages project-scoped persistent notes keyed off the git remote. Quality notes are just another category of project knowledge, so they belong in the same place rather than a parallel system.

## When to persist

Persistence is appropriate when **all** of the following are true:

1. There are 5+ informational notes, **or** the notes describe systemic, cross-cutting issues that span multiple files.
2. The notes cannot be adequately captured as inline code comments -- i.e., they lack a single natural home in the code, describe project-wide patterns, or represent architectural context that would be lost or fragmented if split across comment sites.

If these conditions are not met, present the informational notes inline in the review summary and stop. Inline code comments are usually a better home for "this specific function has a known limitation" than a separate document somewhere.

## Where notes live

Path: `$AGENTS_KB_DIR/projects/<forge>/<owner>/<repo>/quality-notes.md`

- `$AGENTS_KB_DIR` defaults to `~/.knowledge/` if unset.
- `<forge>/<owner>/<repo>` is derived from the project's `origin` git remote:
  - `git@github.com:foo/bar.git` → `github.com/foo/bar`
  - `https://github.com/foo/bar.git` → `github.com/foo/bar`
  - `https://gitlab.com/group/proj` → `gitlab.com/group/proj`
  - Self-hosted forges use the same scheme: `https://git.example.com/foo/bar` → `git.example.com/foo/bar`
- For repos without a configured remote, fall back to `local/<basename-of-repo-root>` and tell the user this is happening; the path won't sync to other machines but will persist locally.

If the `knowledge-base` skill is available in the session, prefer using it to read and write the file rather than touching the path directly -- it ensures the conventions stay in sync. Otherwise, just read and write the markdown file.

## File structure

If the file does not yet exist, create it from this template:

```markdown
# Quality Notes -- <repo name>

Project-scoped quality observations from `quality-review`. These are *informational* findings -- not bugs to fix, but context worth keeping. Reconciled on each review run.

## <Theme heading: e.g., Architecture>

- **<short title>** (`<file>:<line>`) -- <one-line description> -- <why deferred / context>

## <Theme heading: e.g., Design Debt>
...
```

Group entries by theme. Common themes: Architecture, Design Debt, Known Limitations, Testing Gaps, Performance, Cross-cutting Patterns. Use whatever themes fit the actual notes; don't force notes into ill-fitting buckets.

Each entry should include:
- Location reference (`file:line`)
- Concise description of the observation
- Why the issue is being tracked rather than fixed (deferred for capacity, intentional tradeoff, blocked on upstream change, architectural choice that's worth documenting, etc.)

## Reconciliation

On each review run that produces informational notes worth persisting, reconcile against the existing file:

- **Add** notes that are not already covered by an existing entry. A finding is "already covered" if an existing entry describes the same issue at the same or nearby location -- avoid near-duplicates.
- **Remove** entries that are no longer relevant. An entry is stale if the code it references has been changed in a way that resolves or invalidates the concern (the code was deleted, refactored, or the issue was fixed).
- **Update** entries where the nature or location of the issue has shifted -- e.g., the same concern now manifests differently or has moved to a different file.

Report the result in the review summary's Stats line as:

```
- Informational notes: N (tracked in KB -- M added, P removed, Q updated)
```

The intent of reconciliation is to keep the file *current* without churn. Don't delete an entry just because this review didn't independently rediscover it -- only delete when there's positive evidence the underlying concern is gone.
