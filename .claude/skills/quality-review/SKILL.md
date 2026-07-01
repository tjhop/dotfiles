---
name: quality-review
description: Review the current working changes with a domain-expertise pass plus Anthropic's built-in code-review skill, verify the merged findings on a higher-tier model, and present a unified summary for selective action.
disable-model-invocation: true
---

# Quality Review

Review the current working changes, then present the findings for review -- do not auto-fix anything unless explicitly asked.

The skill is a thin orchestrator. It contributes one piece of unique IP -- a **domain-expertise** review -- and delegates everything else to Anthropic's maintained skills (`/code-review` to find correctness + cleanup issues, `/simplify` to apply cleanups). A final higher-tier pass verifies the merged suggestions before anything is shown to you.

## Scope

The review always targets the **current working changes**: files changed on the current branch relative to its merge base with `main`/`master`, plus staged and uncommitted changes. There is no all-vs-branch distinction.

1. Identify the merge base between the current branch and `main`/`master` (`git merge-base HEAD main` or equivalent).
2. Collect the changed file set: `git diff --name-only <merge-base>...HEAD` plus `git diff --name-only` and `git diff --name-only --cached` for uncommitted and staged work.
3. Review the changes themselves *and* their immediate blast radius -- code that directly interacts with or is affected by the change. A bug introduced in `foo.go` may only manifest at a call site in `bar.go`; reviewing the diff in isolation will miss it. Read the surrounding code that directly depends on or is depended upon by the changed code, but only report findings where the change introduced or exposed the issue. Pre-existing problems in unchanged code are out of scope unless the change made them newly reachable or relevant.

**When on `main`/`master`:** there is no feature branch, so don't compute a merge base against the branch itself. The review degenerates to staged + uncommitted changes. If the working tree is also clean (nothing staged, nothing uncommitted), state that there is nothing to review and stop.

## Execution Steps

### 1. Detect Project Context

Before doing anything, quickly determine:

- Primary language(s) and framework(s) (check file extensions, build files, config files)
- Project structure (monorepo, single package, library vs application)
- Available tooling (linters, formatters, test runners -- check Makefile, package.json, pyproject.toml, Cargo.toml, etc.)
- **Current branch, merge base, and changed file list** (per Scope above)

If there is nothing to review (see Scope), say so and stop here.

### 2. Find Phase

The find phase produces two finding-sets that feed the verification pass: the domain-expertise review (this skill's unique value) and Anthropic's `/code-review` (correctness + cleanup).

#### 2a. Domain-Expertise Review (the core unique value)

Spawn **one** domain-expertise agent via the Task/Agent tool:

- `subagent_type: general-purpose` -- it needs web search and Context7/documentation tools that `code-quality-guardian` does not have.
- `model: sonnet` -- run the domain agent on Sonnet.
- Per-subagent effort level is **not** a parameter the Task/Agent tool exposes (only `model` is). Convey "high effort" in the agent's prompt -- instruct it to be thorough, verify against current docs rather than training data, and not stop at the first finding -- rather than passing an effort param that doesn't exist.

A spawned subagent starts with a fresh context and cannot see what the orchestrator computed in step 1. **Pass the scope into the agent's prompt**: the changed file list, the current branch, and the merge base. Without this the agent will review the whole project instead of the current changes.

This agent reviews the changes through the lens of a subject matter expert in the technologies the project works with. It must first research what those technologies are, then evaluate whether the project uses them correctly.

Steps for the agent:
1. **Identify the domain.** Read project documentation (README, CLAUDE.md, doc comments, module description) to understand what the project does and what external tools, protocols, APIs, or systems it interacts with.
2. **Research correct usage.** Use available tools (web search, documentation fetching, Context7) to look up official documentation, best practices, and known pitfalls for the identified technologies. Do not rely solely on training data -- actively verify against current documentation.
3. **Review the changed code as a domain expert.** Evaluate whether the project:
   - Uses APIs, protocols, and data formats correctly according to official specifications
   - Handles edge cases and failure modes that the underlying technology exposes
   - Follows recommended patterns from the technology's ecosystem (not just general programming best practices)
   - Avoids deprecated features, known footguns, or common misuse patterns
   - Models the domain accurately (correct terminology, correct mental model of how the technology works)

Examples of what this looks like in practice:
- A tmux library: Is it using the correct tmux command syntax? Does it handle target formats properly? Does it account for tmux version differences?
- A Prometheus tool: Is it using the HTTP API correctly? Are PromQL queries well-formed? Does it handle staleness, sample limits, and error responses properly?
- A Kubernetes operator: Does it handle finalizers correctly? Are watch/informer patterns used properly? Does it respect API conventions?

The agent must, for every finding:
- Reference specific files and line numbers
- Rate it **high**, **medium**, or **low** priority
- Keep it concise -- one to two sentences per issue
- Classify it as **actionable** or **informational** (defined below)
- Read CLAUDE.md / AGENTS.md / lint configs itself; conventions documented there override general best practices

**Actionable**: The code should change. Covers bugs, logical errors, correctness issues, meaningful improvements, and anything with a clear corrective step -- regardless of priority.

**Informational**: The code is acceptable as-is, but the finding is worth knowing. This includes architectural tradeoffs, deferred design debt, known limitations, cross-cutting patterns that explain non-obvious behavior, and systemic issues that have no single fix. Do not use this classification to soften a real bug or avoid a hard conversation -- if something should be fixed, it is actionable.

#### 2b. Correctness + Cleanup via `/code-review`

Invoke **`/code-review high`** on the current diff. It reports correctness bugs *and* reuse/simplification/efficiency cleanup findings -- this covers what dedicated correctness and maintainability passes used to do, and it's Anthropic-maintained, so don't reimplement it.

- Use the `high` effort tier (passed as the argument, as shown). Broad coverage, may surface some lower-confidence findings -- that's fine; the verification pass filters them.
- **Do not** use `/code-review ultra` -- that's a billed cloud multi-agent mode and is out of scope here.
- **Do not** pass `--fix` or `--comment` in the find phase. This phase only collects findings; fixes happen later and only after you choose them.

`/simplify` is intentionally **not** part of the find phase -- it has no report-only mode (it applies fixes), and `/code-review` already surfaces the cleanup findings. `/simplify` belongs to the apply phase (step 5).

### 3. Verify Phase (higher-tier pass)

After **both** find-phase sources have returned, spawn one verification agent via the Task/Agent tool:

- `model: opus` -- this is the one place Opus is used; the domain agent stays on Sonnet. Spawn it explicitly rather than relying on the orchestrator's own model, since the skill may be invoked from any session.
- `subagent_type: general-purpose` is fine -- no web/doc tools are needed, but it does need to open the repo: hand it the changed file list + merge base and point it at the project so it can Read the referenced files. It checks findings against the actual code; it does not rubber-stamp the merged list.

Give it the merged domain findings + `/code-review` findings (with their file:line refs) and have it adversarially check the suggestions:

- **Deduplicate** across sources. When two findings reference the same file:line range and root cause, merge them into a single entry tagged with both categories (e.g. `[Correctness, Cleanup]`). One finding per real issue, not one per source.
- **Confirm each finding is real** and correctly scoped to the current changes -- not a pre-existing issue in unchanged code, not a misread of the diff.
- **Drop false positives and low-confidence noise.** If a finding can't be substantiated against the actual code, cut it.

The two find-phase sources can have slightly different scope boundaries -- `/code-review` computes its own notion of the diff, which may not exactly match this skill's "merge-base + staged + uncommitted" union. Don't treat "the domain agent flagged something `/code-review` didn't" (or vice versa) as suspicious in itself; judge each finding on its own merits against the code.

The verified, deduplicated set is what gets presented.

### 4. Consolidate Informational Notes

Decide whether the verified informational notes warrant persistence. The full criteria, file template, and reconciliation rules (add/remove/update) live in `references/persistent-notes.md` -- read it when there are informational notes that look durable.

Short version: if there are fewer than ~5 distinct informational notes and each could naturally live as an inline code comment in the file it concerns, skip persistence and inline them in the summary instead. Otherwise, follow the reference doc to persist them.

Notes are persisted to the knowledge base via the `knowledge-base` skill, **not** committed to the repo. This keeps them project-scoped, durable across reviews, and out of the working tree.

### 5. Present the Summary

Present a single, unified, deduplicated summary of the verified findings. Then ask which findings to act on -- do not fix anything until directed.

Output format when informational notes are inlined (no KB persistence):

```
## Quality Review Summary

**Project**: <detected language/framework>
**Reviewed**: <N changed files vs `main`/`master`, plus staged + uncommitted>

### Actionable Findings

#### High Priority
- [Category] file:line - description

#### Medium Priority
- [Category] file:line - description

#### Low Priority
- [Category] file:line - description

### Informational Notes
- [Category] file:line - description

### Stats
- Actionable findings: N (High: N, Medium: N, Low: N)
- Informational notes: N
- By category: Domain (N), Correctness (N), Cleanup (N)
```

When informational notes were persisted to the KB, omit the `### Informational Notes` section and replace its line in Stats with:

```
- Informational notes: N (tracked in KB -- M added, P removed, Q updated)
```

If there are no actionable findings, state that explicitly rather than leaving the section empty. If there are no informational notes at all, omit that section.

### 6. Act on Findings (apply phase)

Only after you select findings to address:

- **Cleanup / simplification items**: delegate to **`/simplify`** -- it applies reuse, simplification, efficiency, and altitude fixes to the working tree.
- **Correctness fixes**: delegate to an implementation agent, or run **`/code-review --fix`** to apply the review's correctness findings.

Commit atomically per fix.

## Notes

- Adapt review criteria to the language and ecosystem. A Go project has different conventions than a Python or TypeScript project. Let the agents use their judgment.
- If the project has a CLAUDE.md, AGENTS.md, or similar configuration that specifies conventions, those take precedence over general best practices.
- If the project has existing linter configurations, note violations of those specifically.
- Do not report style issues that are clearly intentional project conventions.
- Focus on substantive issues over nitpicks. A missing docstring on an internal helper is low priority; a silently discarded error in a public API is high priority.
