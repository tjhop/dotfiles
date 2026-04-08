---
name: knowledge-base
description: >
  Manage a global (`~/.knowledge/`) and project-local (`.knowledge/`) knowledge base
  of research findings organized as trees of markdown files by topic. General technology knowledge
  (Go, Kubernetes, Prometheus, etc.) goes global; project-specific knowledge goes local. Use this
  skill whenever research, investigation, exploration, or information gathering is involved --
  even if the user doesn't mention the knowledge base explicitly. This includes: looking up best
  practices, investigating how something works, exploring new tools or patterns, debugging
  unfamiliar systems, reading external docs/articles, or any task where you'd otherwise kick off
  a subagent for research. Always check both knowledge bases BEFORE starting new research to
  avoid duplicating prior work, and always save meaningful findings AFTER research completes.
  Trigger this skill proactively -- the whole point is that research should never be done twice.
---

# Knowledge Base Skill

You maintain two knowledge bases, organized as trees of markdown files by topic:

- **Global** (`~/.knowledge/`) -- general-purpose knowledge that applies across
  projects. Topics like Go idioms, Kubernetes patterns, Prometheus/PromQL, MCP, tooling
  best practices, etc. live here. If the knowledge is about a technology, language, or
  concept rather than a specific project's implementation, it belongs in global.
- **Project-local** (`.knowledge/` in the project working directory) -- knowledge specific
  to this project's architecture, conventions, quirks, or domain. If the knowledge only
  makes sense in the context of this codebase, it belongs here.

The goal: research done once is captured and reusable -- across conversations, across
agents, across projects, across time. General knowledge shouldn't be re-researched every
time you enter a different project that uses the same technology.

## Core Workflow

Every time research or investigation is part of the task, follow this two-phase flow:

### Phase 1: Check Before Researching

Before doing any new research, exploration, or investigation:

1. Check both knowledge base locations:
   - Global: `~/.knowledge/`
   - Project-local: `.knowledge/` in the project root
2. For each that exists, glob for `**/*.index` files and read them all. These are
   lightweight YAML sidecar files that contain title, tags, triggers, and a short summary
   for each entry. Reading all indexes is cheap and gives you a full picture of what's
   already captured.
3. Match the current task against index `triggers` and `tags`. If any look relevant, read
   the full `.md` file(s) for those entries -- regardless of which knowledge base they're in.
4. If existing knowledge covers the topic well enough, use it directly. Mention to the user
   that you found relevant prior research in the knowledge base.
5. If existing knowledge is partial or outdated, use it as a starting point and note what
   gaps need filling.
6. If nothing relevant exists, proceed with fresh research.

When handing off research context to a subagent, feed it relevant knowledge base content so the
subagent doesn't re-discover what's already known.

### Phase 2: Save After Researching

After completing research that produced meaningful, reusable findings:

1. **Decide where it belongs.** Ask: "Is this knowledge specific to this project, or would
   it be useful in any project that uses this technology/concept?"
   - General technology, language, tool, or concept knowledge --> **global** (`~/.knowledge/`)
   - Project-specific architecture, conventions, or domain knowledge --> **project-local** (`.knowledge/`)
   - When in doubt, prefer global. It's easier to find and benefits more contexts.
2. Check if the topic is already covered by an existing knowledge base file (in either
   location).
   - If yes, update that article with new information and sources, and update the
     index's `last_modified` date.
   - If no, create a new article and index in the appropriate location in the tree.
3. Never create a file for trivial lookups (e.g., checking a single flag value). The bar is:
   "would this save someone real time if they needed this information in a future conversation?"

## File Format

Every knowledge base entry consists of two files:

- `<name>.md` -- the full knowledge base article
- `<name>.md.index` -- a lightweight YAML sidecar for fast scanning

### Index File (`*.md.index`)

The index is the first thing read when scanning the knowledge base. Keep it compact --
its entire purpose is to let you decide whether to read the full article without actually
reading it.

```yaml
title: "<Descriptive topic title>"
last_modified: "YYYY-MM-DD"
tags: [<relevant, topic, tags>]
summary: >
  <2-3 sentences. Enough to know what this covers and whether it's relevant.
  Not a full summary -- just a hook.>
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

**Index rules:**
- `triggers` are the most important field. These are matched against the current task to
  decide relevance. Write them as specific task descriptions, not keywords.
- `summary` should be 2-3 sentences max. If you need more, the full article has it.
- `sources` are title-only here. Full URLs live in the article frontmatter.
- `related` uses relative paths from the index file's location.
- Always create/update the index when creating/updating the article.

### Article File (`*.md`)

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

<2-4 paragraph overview of the topic. What is it, why does it matter, what are the key
concepts. Written so someone unfamiliar can quickly orient themselves.>

## Key Findings

- <Concise, actionable takeaway>
- <Another key finding>
- <Important nuance or caveat>
- <Best practice or recommendation>

## Details

<Deeper content organized by subtopic as needed. Use headings to break up sections.
Include code examples, configuration snippets, metric names, or whatever artifacts
make the knowledge concrete and directly usable.>

## See Also

<Links to related knowledge base entries using relative paths. Only include if genuine
cross-references exist -- don't force connections.>

- [Related Topic](../path/to/related-file.md) - <one-line description of relationship>
```

## Directory Organization

Organize files by topic domain, not by date or conversation. The tree should be intuitive
for a human browsing the directory. Both knowledge bases use the same structure and file
format -- the only difference is what goes where.

**Global** (`~/.knowledge/`) -- general technology knowledge:

```
~/.knowledge/
  go/
    slog-best-practices.md
    error-handling-patterns.md
    module-management.md
  kubernetes/
    memory-monitoring.md
    resource-management.md
    pod-lifecycle.md
  observability/
    promql-patterns.md
    alerting-best-practices.md
    log-query-optimization.md
  grafana/
    dashboard-design.md
    panel-types.md
  tools/
    victoriametrics.md
    victorialogs.md
```

**Project-local** (`.knowledge/`) -- project-specific knowledge:

```
.knowledge/
  architecture/
    service-topology.md
    data-pipeline.md
  conventions/
    error-codes.md
    api-versioning.md
```

Use your judgment. Create subdirectories when a topic area has 3+ files. Keep file names
lowercase-kebab-case and descriptive. The naming and structure should make it possible to
find things without an index file, if needed.

## Rules

1. **Sources are required.** Every file must reference where the information came from.
   Include article titles and URLs. If the source is a conversation or live investigation
   (e.g., querying metrics to discover available labels), say so explicitly.

2. **Summaries are required.** Don't just dump raw notes. Every entry needs a summary that
   orients the reader and a key findings section with highlights.

3. **Triggers live in the index only.** The `.md.index` sidecar's `triggers` and `summary`
   fields are the single source of truth for when an article is relevant. Do not duplicate
   this information in the article body (no "When to Reference This" sections). The article
   itself should focus on the knowledge content. Be specific in index triggers, not generic
   ("useful for Kubernetes work" is too vague; "useful when configuring container memory
   limits or investigating OOM kills" is good).

4. **Check before inserting.** Always scan existing `.index` files in both knowledge
   bases before creating a new entry. If the topic is partially covered elsewhere,
   update that file or add cross-references rather than creating a near-duplicate.

5. **Always create the index.** Every `.md` article must have a corresponding `.md.index`
   sidecar. Create or update both files together -- never one without the other. The
   index is what makes the knowledge base scannable without reading every article.

6. **Cross-reference related entries.** When entries are related, link them with relative
   paths in the "See Also" section and the index `related` field. If updating one file
   and you notice it relates to another, add backlinks in both directions.

7. **Keep entries topic-focused.** One file per concept/topic, not per source. Multiple
   sources feeding into a single topic file is expected and good. The same source
   appearing in multiple topic files is also natural.

8. **Update, don't just append.** When new research augments an existing entry, integrate
   the new information into the existing structure. Add new sources to the article
   frontmatter, update the `last_modified` date in the index, revise the index summary
   and triggers if the scope changed, and revise article content as needed rather than
   tacking new sections onto the bottom.

9. **Respect staleness.** The index `last_modified` date helps gauge freshness. If an
   entry is old and the topic moves fast (e.g., tool versions, API changes), verify key
   claims before relying on them. If you verify and find updates needed, update the
   entry and its index.
