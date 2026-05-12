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
3. Review the changes themselves *and* their immediate blast radius -- code that directly interacts with or is affected by the change. A bug introduced in `foo.go` may only manifest at a call site in `bar.go`; reviewing the diff in isolation will miss it. Read the surrounding code that directly depends on or is depended upon by the changed code, but only report findings where the change introduced or exposed the issue. Pre-existing problems in unchanged code are out of scope unless the change made them newly reachable or relevant.

## Execution Steps

### 1. Detect Project Context

Before spawning agents, quickly determine:

- Primary language(s) and framework(s) (check file extensions, build files, config files)
- Project structure (monorepo, single package, library vs application)
- Available tooling (linters, formatters, test runners -- check Makefile, package.json, pyproject.toml, Cargo.toml, etc.)
- **Current branch, merge base, and changed file list** (when scope is `branch`)

### 2. Build the Agent Brief

Each subagent gets a compact brief containing only what the parent has computed and the agent doesn't already have access to. Do **not** restate what's already in CLAUDE.md, AGENTS.md, .editorconfig, or lint configs -- agents are expected to read those themselves as part of their review, and re-stating them just burns tokens and risks drift between the brief and the source.

Brief format:

```
- Review focus: <Correctness | Maintainability | Domain Expertise>
- Scope: <all | branch>
- Targets: <changed file list when branch scope; "project-wide for the relevant category" when all>
- Branch context (when scope=branch): branch=<name>, base=<merge-base>
```

### 3. Spawn Parallel Review Agents

Launch the following subagents **in parallel** using the Task tool. Each agent must:

- Reference specific files and line numbers for every finding
- Rate each finding as **high**, **medium**, or **low** priority
- Keep findings concise -- one to two sentences per issue
- Classify each finding as either **actionable** or **informational** (defined below)
- Read CLAUDE.md / AGENTS.md / lint configs themselves; conventions documented there override general best practices

**Actionable**: The code should change. Covers bugs, logical errors, correctness issues, meaningful improvements, and anything with a clear corrective step -- regardless of priority.

**Informational**: The code is acceptable as-is, but the finding is worth knowing. This includes architectural tradeoffs, deferred design debt, known limitations, cross-cutting patterns that explain non-obvious behavior, and systemic issues that have no single fix. Do not use this classification to soften a real bug or avoid a hard conversation -- if something should be fixed, it is actionable.

#### Agent 1: Correctness (`subagent_type=code-quality-guardian`)

Review whether the code -- and the tests that validate it -- actually do what they claim. Logic and tests are reviewed together because tautological tests typically only become visible alongside the implementation they're supposed to exercise, and a real defect is often easier to spot when you can also see how the test suite *fails* to catch it.

Code logic:
- Off-by-one errors, boundary conditions, incorrect comparisons
- Race conditions, concurrency issues, unsafe shared state
- Incorrect or incomplete control flow (missing cases, unreachable branches, fallthrough bugs)
- Algorithm correctness -- does the implementation actually do what it claims to?
- Assumptions that may not hold (nil/null dereferences, unchecked casts, implicit ordering)
- Resource leaks (unclosed handles, missing cleanup, deferred operations in wrong scope)

Test correctness:
- Tests that pass regardless of implementation (tautological assertions, assertions on mocks instead of behavior)
- Tests whose names/descriptions don't match what they actually verify
- Missing assertions -- tests that exercise code but never check results
- Tests that depend on implementation details rather than behavior (brittle to refactoring)
- Incorrect test setup that masks bugs (wrong mock behavior, overly permissive matchers)
- Flaky patterns (time-dependent, order-dependent, shared mutable state between tests)

When a code defect and a test gap are linked -- e.g., a tautological test masks a real bug -- report them as a single connected finding rather than two separate ones; the relationship is the most important thing the reader needs to see.

#### Agent 2: Maintainability (`subagent_type=code-quality-guardian`)

Review whether the code is well-structured, well-named, and idiomatic. Simplification and naming/idioms are reviewed together because they're the same concern at different granularities -- a misleading name *is* a readability issue, and non-idiomatic code is often unnecessary complexity dressed up in a different vocabulary.

Simplification and readability:
- Dead code, unused variables, unreachable branches, unnecessary imports
- Over-engineering -- abstractions that serve no purpose, premature generalization
- Code that could be simplified (redundant conditions, convoluted logic, unnecessary indirection)
- Long functions or deeply nested logic that should be broken up
- Copy-pasted code that should be consolidated
- Misleading or stale comments that contradict the code they describe

Naming, consistency, and idioms:
- Naming that violates language conventions (casing, abbreviations, exported vs unexported)
- Inconsistent patterns -- similar things done differently across the codebase
- Non-idiomatic code that has a cleaner standard-library or language-native equivalent
- Violations of conventions established elsewhere in the project (check existing patterns first)
- Structural inconsistencies (file organization, package layout, module boundaries)
- Public API surface clarity -- would a consumer understand how to use this correctly?

#### Agent 3: Domain Expertise (`subagent_type=general-purpose`)

This agent reviews the project through the lens of a subject matter expert in the technologies the project works with. It must first research what those technologies are, then evaluate whether the project uses them correctly. Uses `general-purpose` (not `code-quality-guardian`) because it needs web search and documentation tools that the guardian does not have.

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

### 4. Consolidate and Reconcile Findings

**Deduplicate findings across agents first.** When two findings reference the same file:line range and root cause, merge them into a single entry tagged with both categories. For example, "deeply nested loop with no test coverage" might surface from both Correctness (logic hard to verify) and Maintainability (should be simplified) -- merge into one entry tagged `[Correctness, Maintainability]`. The goal is one finding per real issue, not one per agent. Do this before counting anything, so persistence decisions and stats reflect distinct issues.

**Then decide whether the informational notes warrant persistence.** The full criteria, KB path resolution from the git remote, file template, and reconciliation rules (add/remove/update) live in `references/persistent-notes.md` -- read it when there are informational notes that look durable.

Short version: if there are fewer than ~5 distinct informational notes and each could naturally live as an inline code comment in the file it concerns, skip persistence and inline them in the summary instead. Otherwise, follow the reference doc to write or update `$AGENTS_KB_DIR/projects/<forge>/<owner>/<repo>/quality-notes.md`.

Notes are persisted to the knowledge base, **not** committed to the repo. This keeps them project-scoped, durable across reviews, and out of the working tree.

### 5. Present the Summary

Output format when informational notes are inlined (no KB persistence):

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
- By category: Correctness (N), Maintainability (N), Domain (N)
```

When informational notes were persisted to the KB, omit the `### Informational Notes` section and replace its line in Stats with:

```
- Informational notes: N (tracked in KB -- M added, P removed, Q updated)
```

If there are no actionable findings, state that explicitly rather than leaving the section empty. If there are no informational notes at all, omit that section.

### 6. Act on Findings

After presenting the summary, ask the user which findings (if any) they want to address. Do not proceed with fixes until directed.

When the user selects findings to fix, delegate each fix to the appropriate specialized subagent (implementation, test writing, etc.) and commit atomically per fix.

## Notes

- Adapt review criteria to the language and ecosystem. A Go project has different conventions than a Python or TypeScript project. Let the agents use their judgment.
- If the project has a CLAUDE.md, AGENTS.md, or similar configuration that specifies conventions, those take precedence over general best practices.
- If the project has existing linter configurations, note violations of those specifically.
- Do not report style issues that are clearly intentional project conventions.
- Focus on substantive issues over nitpicks. A missing docstring on an internal helper is low priority; a silently discarded error in a public API is high priority.
