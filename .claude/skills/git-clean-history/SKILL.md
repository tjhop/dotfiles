---
name: git-clean-history
description: Rewrite a branch's local commits into a clean, atomic, signed history before review or push. Use this whenever the user asks to squash, "squash it down", fold or fixup changes into earlier commits, clean up / linearize / make history atomic, amend or reword a commit, rebase onto origin/main (including driving conflict resolution), or get a branch ready to force-push -- even when the ask is just "commit and squash" or "fold it back down so I can review". Also use it to undo a rewrite from a backup ref. Drives a bundled script that snapshots a backup ref, applies one deterministic primitive, and verifies the tree and signatures; never hand-roll commit-tree/update-ref squashes or reach for reset --hard or stash.
argument-hint: "[status|squash|fold|plan|rebase|restore] [--base <ref>]"
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/clean-history.sh:*) Bash(bash ${CLAUDE_SKILL_DIR}/scripts/clean-history.sh:*) Bash(git status:*) Bash(git log:*) Bash(git diff:*) Bash(git show:*) Bash(git range-diff:*) Bash(git rev-parse:*) Bash(git merge-base:*) Bash(git for-each-ref:*) Bash(git fetch:*) Bash(git add:*) Bash(git commit:*) Bash(git rebase --continue) Bash(git rebase --abort) Bash(git branch --show-current)
---

# git-clean-history

Rewriting a feature branch into a reviewable history is a daily ask, and the
ad-hoc ways of doing it have failed in two directions: the safe porcelain
(`reset --soft`, `rebase --autosquash`) got denied and the workaround plumbing
(`commit-tree` + `update-ref`) silently produced unsigned commits. The script at
`${CLAUDE_SKILL_DIR}/scripts/clean-history.sh` is the one sanctioned path. It
refuses unsafe starting states, writes a backup ref before touching anything,
uses porcelain so `commit.gpgsign` and `Signed-off-by` are honoured, and fails
loudly if the resulting tree differs from the original.

Run it as `bash "${CLAUDE_SKILL_DIR}/scripts/clean-history.sh" <subcommand>`.

## Pick the shape

| The user says | Shape | Subcommand |
|---|---|---|
| "squash down to a single/clean commit", commits are WIP noise, PR will be squash-merged | squash to one | `squash` |
| "squash them against the right commits", "fold the fix back into the commit that introduced it" | fold fixes into existing commits | `git commit --fixup=...` then `fold` |
| "reorder", "drop that commit", "collapse these three", N commits should become M | restructure | `plan`, edit, `fold --plan` |
| "rebase onto main", "there's a conflict, drive the rebase", "catch the branch up" | rebase onto a moved base | `rebase --onto origin/main` |
| "undo that", verification failed | restore | `restore <backup-ref>` |

Several shapes often combine: rebase onto main first, then fold, then squash.
Do them as separate script runs so each gets its own backup and verification.

## Always start with `status`

```
bash "${CLAUDE_SKILL_DIR}/scripts/clean-history.sh" status [--base <ref>]
```

It prints the worktree/branch context line (relay it -- the user must never
have to ask "which worktree?"), the commits in range, whether the tree is
clean, whether a rebase is in flight, signing state, and what the push will
need. If it refuses because the tree is dirty, commit the work (a `fixup!`
commit is ideal); if a rebase is in progress, finish or abort it. Never stash
(the stash stack is shared across worktrees and off-limits by policy) and never
`reset --hard`. If the script refuses for any reason, fix the cause; do not
route around it with other git commands.

The base is the merge-base of HEAD and `--base` (default: `origin/main`, then
`origin/master`, `main`, `master`). Pass `--base` explicitly when the branch
stacks on another feature branch.

## Writing the commit message

Write messages to a file under `$TMPDIR` (for example
`$TMPDIR/<branch>-squash.msg`) and pass it with `--message-file`; the script
rejects messages that are not Conventional Commits, exceed 72 characters on the
subject, or lack a body. Structure:

```
type(scope): what changed, in one line

Why the change was needed and what it does, in prose. Markdown is fine, no
emoji. Ticket numbers and PR references belong here, not in code comments.

Assisted-by: Claude Code:<model-id> <noreply@anthropic.com>
Co-Authored-By: <as the session's attribution reminder specifies>
```

Do not add `Signed-off-by` yourself: the script passes `--signoff` when the
branch already carried it. Show the message (and the plan, if any) to the user
before applying unless they said to drive it.

## Squash to one

```
bash "${CLAUDE_SKILL_DIR}/scripts/clean-history.sh" squash --base origin/main --message-file $TMPDIR/x.msg
```

Internally `git reset --soft <base>` followed by `git commit -F`, so the new
commit is signed and the tree is provably identical to the old tip.

## Fold fixes into the commits they belong to

1. Make each fix a fixup of its target, choosing by what changes:
   - content only: `git commit --fixup=<sha>`
   - content and a new message: `git commit --fixup=amend:<sha> -F <msg>`
   - message only: `git commit --fixup=reword:<sha> -F <msg>`
   Stage exactly the files for that target before each commit; one fixup per
   target keeps the fold reviewable.
2. `bash "${CLAUDE_SKILL_DIR}/scripts/clean-history.sh" fold --base <ref>`

`fold` runs `rebase -i --autosquash` with a no-op sequence editor, so nothing
interactive happens and `amend!`/`reword` commits replace the target messages.

## Restructure (reorder, drop, N to M)

```
bash "${CLAUDE_SKILL_DIR}/scripts/clean-history.sh" plan --base <ref> --out $TMPDIR/plan.txt
```

Edit the todo: reorder lines, change `pick` to `fixup` (keep the upper
commit's message) or `fixup -C` (use this commit's message), or `drop`.
`squash` and `reword` are rejected because they need an editor; reword with
`--fixup=reword:` commits and a second, plan-less `fold` instead. Show the
plan to the user, then:

```
bash "${CLAUDE_SKILL_DIR}/scripts/clean-history.sh" fold --base <ref> --plan $TMPDIR/plan.txt
```

An omitted line is an error, not a silent drop.

## Rebase onto a moved base

```
bash "${CLAUDE_SKILL_DIR}/scripts/clean-history.sh" rebase --onto origin/main
```

Fetches the remote first (`--no-fetch` to skip). Exit code 2 means the rebase
stopped on conflicts and the branch is mid-rebase; the script lists the files.
Resolve each one, `git add` it, run `git rebase --continue` (no editor opens:
the harness exports `GIT_EDITOR=true`), repeat until the rebase finishes, then
run `verify` with no arguments to get the checks and the report. Do not
`--abort` to dodge a conflict; if the rebase should be abandoned, say so and
run `restore` with the printed backup ref.

## Verification and the report

After every rewrite the script checks, and you relay:

- tree identical to the old tip (squash/fold; hard failure otherwise) or, for a
  rebase, whether the branch's diff against its base changed;
- every commit in range signed when `commit.gpgsign` is set; `Signed-off-by`
  carried when the branch used it;
- a `range-diff` of old vs new when more than one commit remains;
- the context line, `git log --oneline` of the result, and the exact push
  command, with `--force-with-lease` pinned to the remote tip when history was
  rewritten.

Relay the context line, the log, and the push command. Never run the push:
pushing is the user's call, always. If verification fails (exit 3), run the
printed `restore` command and report what differed.

## Undo

Backups live under `refs/backup/<branch>/<utc-timestamp>` and survive `gc`.

```
git for-each-ref refs/backup/<branch>/
bash "${CLAUDE_SKILL_DIR}/scripts/clean-history.sh" restore refs/backup/<branch>/<ts>
```

## Why these primitives

- `reset --soft` + `commit` and `rebase` are porcelain: they sign, add
  `--signoff`, and run hooks. `commit-tree`/`update-ref` skip all of that;
  four pushed branch tips were found unsigned on 2026-09-14 for exactly this
  reason. Do not use them for squashes.
- `GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash` works on every git
  version; bare `rebase --autosquash` needs 2.44+.
- Backup refs are real refs, so recovery never needs `reset --hard` or reflog
  spelunking: `restore` updates the index and work tree with `read-tree -u -m`
  and moves the branch with a compare-and-swap `update-ref`.
- After editing the script, run `scripts/selftest.sh`; it exercises every
  subcommand, refusal, and conflict path against throwaway repos in `$TMPDIR`.
