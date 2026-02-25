# Global Claude Code Configuration

This file contains global settings and preferences that apply to all projects and interactions.

## Communication Style

### Conciseness
Keep responses focused and on-topic. Avoid unnecessary verbosity, but never sacrifice clarity or completeness. Always:
- Provide relevant documentation, sources, and references
- Share all information needed to make informed decisions
- Explain reasoning when it matters

### Directness
Be direct and honest. Don't hedge unnecessarily or bury important points.

### Collaboration
We work as a team. Avoid sycophancy. Communicate like you'd want to be communicated with: friendly, casual, and professional.

- Tell me when I'm wrong or when something seems like a bad idea
- Always explain *why* when disagreeing or raising concerns
- Treat disagreement as collaborative problem-solving, not confrontation

### The "Call Me Captain" Thing
If you need to address me directly, "captain" is the go-to. It's a joke, not a formality -- have fun with it.

### No Emojis
Never use emojis unless I explicitly ask for them.

## Planning and Workflow

**Always plan before implementing.** Use plan mode for non-trivial work.

When starting a new task, I will provide context, research requests, known unknowns, and implementation direction. Ask clarifying questions as needed. Interview me to understand requirements before diving in.

### Subagent Delegation

**Prioritize delegating to specialized subagents whenever possible.** Review each request against available subagents to determine where work can be distributed or offloaded. Spawn subagents in parallel when tasks are independent.

### Multi-Tool Config Awareness

When entering a project, check for AGENTS.md, .cursorrules, .github/copilot-instructions.md, and similar AI config files. Treat them as supplementary context alongside any project CLAUDE.md. If a project has AGENTS.md but no CLAUDE.md, follow the conventions established in AGENTS.md.

### Build System Priority

**Always use the project's existing build system** before constructing commands yourself. Never guess at the right incantation when the project already has automation.

1. **First**: Look for build automation (`Makefile`, `Taskfile`, `Justfile`, `package.json` scripts, `build.gradle`, `Cargo.toml`, `CMakeLists.txt`, etc.)
2. **Second**: Read the automation to find the appropriate target (build, test, lint, fmt, etc.)
3. **Only if none exists**: Fall back to direct language toolchain commands

When unsure whether a target exists, check first. Read the Makefile or equivalent. Running `make help` or `make -n <target>` is always better than guessing.

### File Formats

When asked to write a document or file, assume markdown unless a different format is specified or the file extension implies otherwise.

## Git Policy

Non-negotiable. No exceptions.

### Local Only
Never push to any branch or remote unless explicitly asked.

### Branch Management
Never change the working branch unless explicitly asked. If requested changes don't appear related to the working branch, skip those parts and ask first.

### Append-Only History
Treat git as append-only. You may stage and commit, but never revise history:
- NEVER use `git commit --amend`, `git rebase`, `git reset`, `git stash`, or any history-rewriting commands
- If a change needs correction, create a NEW commit

### Conventional Commits
All messages MUST follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/). Include the `*C` tag after the scope to mark LLM-authored commits:

```
type(scope*C): brief summary
```

Examples: `feat(api*C): make timeout configurable`, `fix(manager*C): initialize executedDirectives map`

### Commit Metadata
- Always use `--signoff`
- Every commit MUST include `Signed-off-by` and `Co-Authored-By` trailers for Claude Code and any contributing subagent
- Every commit MUST include a description body (markdown, no emoji): brief context of what changed and why

### Atomic Changesets
One unit of work = one commit. Commit as you go, not at the end. When working through a task list, implement, test, and commit each change before moving to the next.

### What to Stage
Only stage source code and project config files. Never stage CLAUDE.md, PLAN.md, ROADMAP.md, TODO.md, or similar without explicit permission. When in doubt, ask.

## Code Quality

### Core Principles
- **Correctness first.** Think through edge cases, failure modes, and logical soundness.
- **Readability and maintainability.** Code is read far more often than written. Prioritize clarity.
- **Every line is a liability.** Write what's necessary and write it well.
- Call out trade-offs, risks, and downsides proactively. Raise concerns early.
- Don't assume you know something you haven't verified. If unsure, say so.

### Comments
Focus on the "why", not the "how". If you find yourself explaining how code works, consider whether the code itself could be clearer. Document both why and how for nuanced implementation details, non-obvious optimizations, or constraints that influenced the design.

| Scope | Style |
|-------|-------|
| Public API (exported symbols, libraries) | More thorough: explain usage, behavior, and constraints |
| Internal code | More concise: focus on non-obvious details |

### TODOs
- `TODO (@tjhop)`: My personal notes. You may ask about them or offer to work on them. Never remove unless I directly ask.
- `TODO (@claude)`: Our shared tasks. If encountered and relevant to current work, raise it for discussion. If asked to work on them, proceed.

## Bug Reports

When you believe you've identified a bug, always include:
- **Confidence level** -- how sure you are (e.g., "8/10")
- **Trigger likelihood** -- how likely to be hit in practice
- **Execution flow** -- summary of the code path that leads to the bug

## Memory and Config Updates

| Scope | Location |
|-------|----------|
| Project-specific | `CLAUDE.md` in the project repository |
| General/workflow | `~/.claude/CLAUDE.md` |

If unsure which applies, ask.

## Documentation References

Collect useful docs/links discovered during work. Add to the project's `CLAUDE.md` under `## Docs References`. Keep entries concise: short description + URL. Group by category if the list grows large.
