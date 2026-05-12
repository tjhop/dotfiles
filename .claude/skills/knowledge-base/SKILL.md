---
name: knowledge-base
description: >
  Manage a global knowledge base of research findings as trees of markdown
  files by topic; lives at `$AGENTS_KB_DIR` (default `~/.knowledge/`). General
  technology knowledge (Go, Kubernetes, Prometheus, etc.) goes under top-level
  domain dirs; project-specific knowledge goes under
  `projects/<forge>/<owner>/<repo>/` derived from the git remote. Use this
  skill whenever research, investigation, exploration, or information gathering
  is involved -- looking up best practices, learning how something works,
  exploring new tools or patterns, debugging unfamiliar systems, reading
  external docs, or anywhere you'd otherwise spawn a research subagent. Always
  check the KB before starting new research and save meaningful findings after
  -- the whole point is that research should never be done twice.
---

# Knowledge Base Skill

You maintain a single knowledge base at a path we'll call the **KB dir**,
organized as a tree of markdown files by topic. The tree has two areas:

- **General knowledge** -- top-level domain dirs (`go/`, `kubernetes/`,
  `observability/`, ...) for tech, language, tool, or concept knowledge that
  applies across projects.
- **Project-specific knowledge** -- under `projects/<forge>/<owner>/<repo>/`,
  for architecture, conventions, quirks, or domain knowledge tied to one repo.

The goal: research done once is captured and reusable -- across conversations,
across agents, across projects, across time.

## Resolving Paths

The bundled `bin/kb` helper is the canonical way to resolve paths. It uses the
same rule as this skill (`$AGENTS_KB_DIR` if set and non-empty, else
`$HOME/.knowledge`), so the helper and the skill cannot disagree. Always
invoke it via `bash` so it works without the executable bit, which can be lost
when files traverse sandboxes, archives, or `git restore`:

```sh
bash ~/.claude/skills/knowledge-base/bin/kb where    # resolved KB dir
bash ~/.claude/skills/knowledge-base/bin/kb help     # all subcommands
```

Resolve once at session start and remember the value for the conversation. If
the resolved KB dir doesn't exist yet, that's fine -- it's created on the
first write. Don't fail the read path because nothing has been saved yet.

For sandboxed or otherwise restricted machines where `$HOME` may not be
writable, see `references/per-machine-setup.md`.

### Project path

For project-specific knowledge, derive the project ID from the git remote
origin URL by stripping protocol, `git@` prefix, and `.git` suffix:

```
git@github.com:tjhop/monster-mash.git     -> github.com/tjhop/monster-mash
https://github.com/tjhop/monster-mash.git -> github.com/tjhop/monster-mash
```

Project knowledge then lives at `<KB dir>/projects/<forge>/<owner>/<repo>/`.

For local-only repos with no remote, fall back to
`projects/local/<8-char-hash-prefix>-<dirname>` (hash of the absolute project
root). Run `git remote get-url origin` once and remember the resolved path.

## Core Workflow

Every time research or investigation is part of the task, follow this two-phase
flow.

### Phase 1: Check Before Researching

Before doing any new research, exploration, or investigation:

1. Run `bash bin/kb ls` (or glob for `<KB dir>/**/*.md.index` and read them).
   These are lightweight YAML sidecars with title, tags, triggers, and a short
   summary per entry. Reading all indexes is cheap and gives you a full picture
   of what's already captured -- general and project-specific.
2. Match the current task against `triggers` and `tags`. If any look relevant,
   read the full `.md` file(s).
3. If existing knowledge covers the topic well enough, use it directly and
   mention to the user that you found relevant prior research in the KB.
4. If existing knowledge is partial or outdated, use it as a starting point and
   note what gaps need filling.
5. If nothing relevant exists, proceed with fresh research.

When handing off to a research subagent, feed it the relevant KB content so
the subagent doesn't re-discover what's already known.

### Phase 2: Save After Researching

After research that produced meaningful, reusable findings:

1. **Decide where it belongs.** Ask: "Is this specific to this project, or
   would it be useful in any project that uses this technology?"
   - General tech/language/tool/concept knowledge --> top-level domain dir
     (e.g., `<KB dir>/go/`, `<KB dir>/kubernetes/`).
   - Project-specific architecture, conventions, or domain --> project subtree
     (e.g., `<KB dir>/projects/github.com/tjhop/monster-mash/conventions/`).
   - When in doubt, prefer the top level. It's easier to find and benefits
     more contexts.
2. **Check whether the topic is already covered.** If yes, update that article
   in place and bump the index's `last_modified`. Don't create near-duplicates.
3. **Don't bother with trivial lookups** (a single flag value, a one-off type
   signature). The bar is: "would this save someone real time if they needed
   this in a future conversation?"

`bash bin/kb new <topic/path>` scaffolds an article + index pair with the
right frontmatter -- use it to skip boilerplate.

## File Format

Every entry is two files:

- `<name>.md` -- the full article.
- `<name>.md.index` -- a lightweight YAML sidecar for fast scanning.

The pair lives or dies together. Always create or update both.

### Index file (`*.md.index`)

The index is what you read first when scanning the KB. Keep it compact -- its
whole purpose is to let you decide whether to read the article without
actually reading it.

```yaml
title: "<Descriptive topic title>"
last_modified: "YYYY-MM-DD"
tags: [<relevant, topic, tags>]
summary: >
  <2-3 sentences. Enough to know what this covers and whether it's relevant.
  Not a full summary -- a hook.>
triggers:
  - "<Specific task or question where this entry is useful>"
  - "<Another scenario>"
  - "<Be concrete, not generic>"
sources:
  - "<Source title 1>"
  - "<Source title 2>"
related:
  - <relative/path/to/related-file.md>
```

`triggers` is the most important field: it's what's matched against the
current task to decide relevance. Write triggers as specific task descriptions,
not keywords. "useful for Kubernetes work" is too vague; "useful when
configuring container memory limits or investigating OOM kills" is good. The
index sidecar is the single source of truth for trigger metadata -- don't
duplicate triggers or "when to reference this" sections in the article body.
Full source URLs live in the article frontmatter, not here.

### Article file (`*.md`)

```markdown
---
sources:
  - title: "<Article/doc title>"
    url: "<URL if available>"
  - title: "<Another source>"
    url: "<URL>"
---

# <Topic Title>

## Summary

<2-4 paragraph overview. What is it, why does it matter, what are the key
concepts. Written so someone unfamiliar can quickly orient themselves.>

## Key Findings

- <Concise, actionable takeaway>
- <Another key finding>
- <Important nuance or caveat>
- <Best practice or recommendation>

## Details

<Deeper content organized by subtopic. Use headings to break up sections.
Include code examples, configuration snippets, metric names, or whatever
artifacts make the knowledge concrete and directly usable.>

## See Also

<Links to related KB entries, relative paths. Only include if genuine
cross-references exist -- don't force connections.>

- [Related Topic](../path/to/related-file.md) - <one-line description>
```

## Directory Organization

Organize files by topic domain, not by date or conversation. The tree should
be intuitive for a human browsing the dir. Examples (substitute whatever
`bash bin/kb where` reports for the KB root):

```
<KB dir>/
  go/
    slog-best-practices.md
    error-handling-patterns.md
  kubernetes/
    memory-monitoring.md
  observability/
    promql-patterns.md
  projects/
    github.com/tjhop/monster-mash/
      architecture/
        service-topology.md
      conventions/
        error-codes.md
```

Use your judgment. Create subdirs when a topic area has 3+ files. Names should
be lowercase-kebab-case and descriptive enough that things are findable
without an index, if needed.

## Helper CLI

The bundled helper at `~/.claude/skills/knowledge-base/bin/kb` provides
`where`, `ls`, `grep`, `new`, and `path` subcommands. Run
`bash ~/.claude/skills/knowledge-base/bin/kb help` for current usage. Always
invoke via `bash` (not direct exec) so it works without the executable bit.

## Rules

1. **Sources are required.** Every article must reference where the
   information came from -- titles and URLs in the article frontmatter. If the
   source is a live investigation (querying metrics to discover labels, reading
   running code), say so explicitly.

2. **Summaries are required.** Don't dump raw notes. Every article needs a
   Summary and Key Findings section that orients the reader.

3. **Cross-reference related entries.** Link related articles via the `See
   Also` section and the index `related` field, with relative paths. If you're
   updating one file and notice it relates to another, add backlinks in both
   directions.

4. **Keep entries topic-focused.** One file per concept, not per source.
   Multiple sources feeding into a single topic file is expected and good. The
   same source appearing in multiple topic files is also natural.

5. **Update, don't append.** When new research augments an existing entry,
   integrate it into the existing structure: add new sources to the article
   frontmatter, update the index `last_modified`, revise the index summary and
   triggers if scope changed, and revise article content in place rather than
   tacking new sections onto the bottom.

6. **Respect staleness.** The index `last_modified` date helps gauge freshness.
   If an entry is old and the topic moves fast (tool versions, API changes),
   verify key claims before relying on them. If you find changes needed,
   update the entry and its index.
