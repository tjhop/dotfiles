---
name: quality-review
description: Run parallel quality review agents across the codebase. Spawns specialized sub-agents for different quality concerns and presents a unified summary of findings for selective action.
disable-model-invocation: true
argument-hint: [all|branch]
---

# Quality Review

Run a parallel quality review across the codebase. Findings are presented for review -- do not auto-fix anything unless explicitly asked.

## Scope

The positional argument (`$ARGUMENTS`) controls what code is reviewed:

- **`branch`** (default, used when no argument is provided): Scope the review to files changed on the current working branch. This mode only applies when the current branch is **not** `main` or `master`. If invoked with `branch` while on `main`/`master`, fall back to `all` and note this in the output.
- **`all`**: Review all code in the project relevant to each review category.

### Branch Scope Details

When scope is `branch`:

1. Identify the merge base between the current branch and `main`/`master` (`git merge-base HEAD main` or equivalent).
2. Collect the set of files modified in commits since the merge base **and** any staged but uncommitted changes (`git diff --name-only <merge-base>...HEAD` plus `git diff --name-only --cached`).
3. These files are the **primary review targets**. Each review agent should focus its analysis on them.
4. Agents should also consider the **immediate blast radius** of those changes: callers, call sites, interfaces, and types that directly depend on or are depended upon by the changed code. This surrounding context should be read and understood, but findings should only be reported when the changed code introduces or exposes a problem in that surrounding context -- do not report pre-existing issues in unchanged code.

## Execution Steps

### 1. Detect Project Context

Before spawning agents, quickly determine:

- Primary language(s) and framework(s) (check file extensions, build files, config files)
- Project structure (monorepo, single package, library vs application)
- Available tooling (linters, formatters, test runners -- check Makefile, package.json, pyproject.toml, Cargo.toml, etc.)
- Existing style conventions (check for .editorconfig, lint configs, CLAUDE.md guidelines)
- **Current branch and merge base** (when scope is `branch`)
- **Changed file list** (when scope is `branch`)

This context -- including the resolved scope and file list when applicable -- is passed to each sub-agent so they can tailor their analysis.

### 2. Spawn Parallel Review Agents

Launch the following sub-agents **in parallel** using the Task tool with `subagent_type=code-quality-guardian`. Each agent should be given the detected project context and scope.

#### Agent 1: Logical Correctness

Review code and algorithms for logical soundness:
- Off-by-one errors, boundary conditions, incorrect comparisons
- Race conditions, concurrency issues, unsafe shared state
- Incorrect or incomplete control flow (missing cases, unreachable branches, fallthrough bugs)
- Algorithm correctness -- does the implementation actually do what it claims to?
- Assumptions that may not hold (nil/null dereferences, unchecked casts, implicit ordering)
- Resource leaks (unclosed handles, missing cleanup, deferred operations in wrong scope)

#### Agent 2: Simplification and Readability

Review for opportunities to reduce complexity and improve maintainability:
- Dead code, unused variables, unreachable branches, unnecessary imports
- Over-engineering -- abstractions that serve no purpose, premature generalization
- Code that could be simplified (redundant conditions, convoluted logic, unnecessary indirection)
- Long functions or deeply nested logic that should be broken up
- Copy-pasted code that should be consolidated
- Misleading or stale comments that contradict the code they describe

#### Agent 3: Test Correctness

Review tests for whether they actually validate what they claim to:
- Tests that pass regardless of implementation (tautological assertions, assertions on mocks instead of behavior)
- Tests whose names/descriptions don't match what they actually verify
- Missing assertions -- tests that exercise code but never check results
- Tests that depend on implementation details rather than behavior (brittle to refactoring)
- Incorrect test setup that masks bugs (wrong mock behavior, overly permissive matchers)
- Flaky patterns (time-dependent, order-dependent, shared mutable state between tests)

#### Agent 4: Naming, Consistency, and Idioms

Review for adherence to language idioms, project conventions, and internal consistency:
- Naming that violates language conventions (casing, abbreviations, exported vs unexported)
- Inconsistent patterns -- similar things done differently across the codebase
- Non-idiomatic code that has a cleaner standard-library or language-native equivalent
- Violations of conventions established elsewhere in the project (check existing patterns first)
- Structural inconsistencies (file organization, package layout, module boundaries)
- Public API surface clarity -- would a consumer understand how to use this correctly?

#### Agent 5: Domain Expertise

This agent reviews the project through the lens of a subject matter expert in the technologies the project works with. It must first research what those technologies are, then evaluate whether the project uses them correctly.

Steps:
1. **Identify the domain.** Read project documentation (README, CLAUDE.md, doc comments, module description) to understand what the project does and what external tools, protocols, APIs, or systems it interacts with.
2. **Research correct usage.** Use available tools (web search, documentation fetching, Context7) to look up official documentation, best practices, and known pitfalls for the identified technologies. Do not rely solely on training data -- actively verify against current documentation.
3. **Review the code as a domain expert.** Evaluate whether the project:
   - Uses APIs, protocols, and data formats correctly according to official specifications
   - Handles edge cases and failure modes that the underlying technology exposes
   - Follows recommended patterns from the technology's ecosystem (not just general programming best practices)
   - Avoids deprecated features, known footguns, or common misuse patterns
   - Models the domain accurately (correct terminology, correct mental model of how the technology works)

Examples of what this looks like in practice:
- A tmux library: Is it using the correct tmux command syntax? Does it handle target formats properly? Does it account for tmux version differences?
- A Prometheus tool: Is it using the HTTP API correctly? Are PromQL queries well-formed? Does it handle staleness, sample limits, and error responses properly?
- A Kubernetes operator: Does it handle finalizers correctly? Are watch/informer patterns used properly? Does it respect API conventions?

This agent should use `subagent_type=general-purpose` (not code-quality-guardian) since it needs access to web search and documentation tools for research.

Each agent must:
- Reference specific files and line numbers for every finding
- Rate each finding as **high**, **medium**, or **low** priority
- Keep findings concise -- one to two sentences per issue
- Classify each finding as either **actionable** or **informational** (defined below)

**Actionable**: The code should change. Covers bugs, logical errors, correctness issues, meaningful improvements, and anything with a clear corrective step -- regardless of priority.

**Informational**: The code is acceptable as-is, but the finding is worth knowing. This includes: architectural tradeoffs, deferred design debt, known limitations, cross-cutting patterns that explain non-obvious behavior, and systemic issues that have no single fix. Do not use this classification to soften a real bug or avoid a hard conversation -- if something should be fixed, it is actionable.

### 3. Compile Results

After all agents complete, compile their findings. **Check whether a `QUALITY.md` exists in the project root before formatting output** -- this controls how informational notes are presented (see Step 4).

When `QUALITY.md` does **not** exist, use this full format:

```
## Quality Review Summary

**Scope**: <all | branch (N files from branch `branch-name`)>
**Project**: <detected language/framework>

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
- By category: Correctness (N), Simplification (N), Tests (N), Naming/Idioms (N), Domain (N)
```

When `QUALITY.md` **exists**, omit the Informational Notes section from the output and replace it with a single status line after Stats (see Step 4 for how to produce it):

```
## Quality Review Summary

**Scope**: <all | branch (N files from branch `branch-name`)>
**Project**: <detected language/framework>

### Actionable Findings

#### High Priority
- [Category] file:line - description

#### Medium Priority
- [Category] file:line - description

#### Low Priority
- [Category] file:line - description

### Stats
- Actionable findings: N (High: N, Medium: N, Low: N)
- Informational notes: N (tracked in QUALITY.md -- M added, P removed, Q updated)
- By category: Correctness (N), Simplification (N), Tests (N), Naming/Idioms (N), Domain (N)
```

In both cases: if there are no actionable findings, state that explicitly rather than leaving the section empty. If there are no informational notes, omit that section (or zero out the counts in the stats line).

### 4. Reconcile or Create QUALITY.md

Before presenting the summary to the user, handle informational notes as follows based on whether `QUALITY.md` already exists.

#### If QUALITY.md exists

Reconcile the informational notes from this review against the existing document:

- **Add** findings not already covered by an existing entry. A finding is "already covered" if an existing entry describes the same issue at the same or nearby location -- do not add near-duplicates.
- **Remove** entries that are no longer relevant. An entry is stale if the code it references has been changed in a way that resolves or invalidates the concern (e.g., the code was deleted, refactored, or the issue was fixed).
- **Update** entries where the nature or location of the issue has shifted -- e.g., the same concern now manifests differently or has moved to a different file.

After reconciling, update `QUALITY.md` in place. Do not show the informational notes inline in the review summary. Instead, include only the stats line described in Step 3: `N added, P removed, Q updated`. Tell the user to review the document for informational context. Keep the review output focused on actionable findings.

#### If QUALITY.md does not exist

Evaluate whether the informational notes warrant creating a persistent `QUALITY.md`. A dedicated document is only appropriate when **all** of the following are true:

1. There are **5 or more** informational notes, **or** the notes describe systemic, cross-cutting issues that span multiple files.
2. The notes cannot be adequately captured as inline code comments -- i.e., they lack a single natural home in the code, describe project-wide patterns, or represent architectural context that would be lost or fragmented if split across comment sites.

If these conditions are met, offer to create the document after presenting the summary. Do not create it automatically. Describe what it would contain and why inline comments are insufficient for this particular content.

If a `QUALITY.md` is created:
- It should group notes by theme (e.g., Architecture, Design Debt, Known Limitations, Testing Gaps).
- Each entry should include: location reference, a concise description, and why it is deferred rather than fixed.
- After creating the file, check for a `CLAUDE.md` in the project root. If one exists, add a brief reference to `QUALITY.md` so future sessions are aware of it. If none exists, note this to the user but do not create one unprompted.

### 5. Present for Action

After presenting the summary, ask the user which findings (if any) they want to address. Do not proceed with fixes until directed.

When the user selects findings to fix, delegate each fix to the appropriate specialized sub-agent (implementation, test writing, etc.) and commit atomically per fix.

## Notes

- Adapt review criteria to the language and ecosystem. A Go project has different conventions than a Python or TypeScript project. Let the agents use their judgment.
- If the project has a CLAUDE.md or similar configuration that specifies conventions, those take precedence over general best practices.
- If the project has existing linter configurations, note violations of those specifically.
- Do not report style issues that are clearly intentional project conventions.
- Focus on substantive issues over nitpicks. A missing docstring on an internal helper is low priority; a silently discarded error in a public API is high priority.
