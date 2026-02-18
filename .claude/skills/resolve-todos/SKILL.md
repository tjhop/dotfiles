---
name: resolve-todos
description: Resolve TODO code comments addressed to @claude that are related to the current git branch
disable-model-invocation: true
---

# Resolve TODOs Skill

This skill finds and resolves `TODO (@claude)` comments in the codebase that are relevant to the current git branch.

## Comment Format

Only process comments matching this exact pattern:

```
TODO (@claude): <description>
```

Variations like `TODO(@claude)`, `TODO: @claude`, or `TODO (claude)` should NOT be processed. The format must be `TODO (@claude):` with the space and parentheses.

**Important**: Never touch `TODO (@tjhop)` comments - these are personal notes and must not be removed or modified unless the user explicitly asks.

## Execution Steps

### 1. Determine Branch Context

First, understand what the current branch is working on:

```bash
git branch --show-current
git log --oneline -10
```

Review the branch name and recent commits to understand the scope of work. This context determines which TODOs are "relevant" to resolve.

### 2. Find TODO Comments

Search for `TODO (@claude)` comments across the codebase:

```bash
grep -rn "TODO (@claude):" --include="*.go" --include="*.md" --include="*.yaml" --include="*.yml" .
```

Or use the Grep tool with pattern `TODO \(@claude\):`.

### 3. Filter for Relevance

For each TODO found, evaluate whether it is relevant to the current branch by considering:

- Does the TODO relate to files/packages being modified in this branch?
- Does the TODO's subject matter align with the branch's purpose?
- Is the TODO in a file that shares context with current work?

**Skip TODOs that are unrelated to the current branch.** If unsure, ask the user for clarification.

### 4. Interpret and Clarify

For each relevant TODO:

1. **Read the surrounding code** to understand the context
2. **Interpret the intent** - what is the TODO actually asking for?
3. **Identify unknowns** - what information is missing?
4. **Ask clarifying questions** if the task is ambiguous or requires decisions

Present your interpretation to the user before proceeding. Example:

> Found `TODO (@claude): refactor this to use the new API client` at `pkg/foo/bar.go:42`.
>
> I interpret this as: Replace the direct HTTP calls with the shared API client from `pkg/api/client.go`. Should I proceed with this approach, or did you have something different in mind?

### 5. Delegate to Subagents

Use the Task tool to delegate work to the appropriate specialized subagent based on what the TODO requires:

- For code exploration or understanding context, use an exploration-focused agent
- For planning complex changes, use a planning agent
- For implementing code changes, use an implementation agent
- For writing or validating tests, use a testing agent
- For code quality review, use a quality-focused agent
- For build validation, use a build/compiler agent

Review the available subagent types and their descriptions to select the best match for each task. When multiple independent tasks can run in parallel, spawn subagents concurrently.

For multi-step TODOs, create a task list and work through each item, committing atomically as you go.

### 6. Remove the TODO

After successfully completing the work described in the TODO:

1. Remove the `TODO (@claude):` comment from the code
2. If appropriate, replace it with a regular code comment explaining the implementation (only if non-obvious)
3. Include the TODO resolution in your commit message

## Example Workflow

```
User: /resolve-todos

Claude:
1. Checks current branch: `feature/add-retry-logic`
2. Finds TODOs:
   - `pkg/api/client.go:87` - TODO (@claude): add retry with backoff
   - `pkg/db/conn.go:23` - TODO (@claude): consider connection pooling
   - `docs/README.md:15` - TODO (@claude): update installation instructions

3. Filters for relevance:
   - client.go TODO: RELEVANT (matches branch purpose)
   - conn.go TODO: NOT RELEVANT (unrelated to retry logic)
   - README.md TODO: NOT RELEVANT (documentation, not retry logic)

4. Asks clarifying questions:
   "The TODO asks for retry with backoff. Should I use exponential backoff?
    What should the max retries be? Should this be configurable?"

5. After clarification, delegates to the appropriate subagent for implementation

6. Removes the TODO comment and commits the change
```

## Error Handling

- If no `TODO (@claude)` comments are found, report this to the user
- If all found TODOs are irrelevant to the current branch, explain why and ask if the user wants to proceed anyway
- If a TODO is unclear or seems outdated, ask the user before acting on it
- Never silently skip TODOs - always explain what was found and what action was taken

