# Walkthrough reference

How to find the open items in a session, how to group and rank them, how to
record answers, what a pause looks like, and what the decision log at the end
looks like.

## Where open items hide

Read the session from the start, not only the last few turns; the items the
user has forgotten about are the ones a huddle exists to surface. Look for:

- **Unanswered questions in earlier assistant turns.** A question that the
  user replied past ("ok, also can you...") is still open. So is the second
  of two stacked questions when the user answered only the first.
- **`needs input:` lines.** In a background job that reports with them,
  these are the whole inventory. Elsewhere, any such line without a later
  answer is open.
- **`TODO (@claude)` markers** in diffs you wrote or reviewed, and
  `TODO`/`FIXME` lines you added and did not resolve.
- **Failing checks left unresolved.** A test, lint, `git diff --check`, CI
  run, or validation command that failed and was set aside ("will look at
  this later", "unrelated", "skipping for now").
- **Assumptions.** Sentences that start with or contain "assuming", "I'll
  proceed with", "I went with", "for now", "probably", "should be fine".
  Each one is a decision made without the user; list it unless the user
  later confirmed it.
- **Deferred decisions.** "We can decide X later", "leaving Y as is until",
  "option B for now".
- **Promised follow-ups.** "I'll check X after this", "once the PR merges
  I'll update the ticket", "I'll circle back to".
- **Blocked tasks.** Anything stopped on auth, a missing tool, the sandbox,
  a pending review, or another person.
- **Background work.** Agents or jobs started in this session whose result
  has not been read or reported.
- **Side asks.** A script you handed the user to run, a key you asked them
  to fetch, an "if you want it, say so" offer. Each is an item with a
  number, never a line in a status preamble.
- **Decided, awaiting the go.** Outward writes or pushes decided in an
  earlier huddle and parked for the user's "post" or "push". They are one
  grouped item with the options run or hold, not fresh briefs.

Before listing an item, check the session's decision record. An item the
record already shows as decided is not open; re-ask a standing decision only
when a new fact has arrived, and name the fact in the brief. An item that is
not ready to decide ("wait for the review verdict first") is not open either;
it goes under "For the record" with what it is waiting on.

Do not list things that are merely in progress and need nothing from the
user unless they are blocked. The inventory is what needs the user's
attention or a decision, not a status report. Information with nothing to
decide goes under "For the record" in one line each.

## Grouping

Two to five items that need the same kind of decision with the same option
set are one grouped item. The test is whether one set of lettered options
reads naturally against every sub-item:

- three stale worktrees: delete, keep, or hand to the user;
- four closed tickets with open children: reopen, leave closed, or skip;
- two config scripts drafted for the user: approve, change, or drop;
- six unlinked PRs: attach to the ticket named, new ticket, or ignore.

Sub-items are numbered 1 to k inside the group and carry one line of
evidence each; the shared What, Why, options, reversibility, and question
are written once. The recommendation is per sub-item ("A for 1 and 3, B for
2") or "A for all". Six or more become two groups. Items whose options
differ stay separate even when the topic is the same; a shared theme is not
a shared decision.

A dependent item folds into its parent as an option or a consequence rather
than taking its own number: if answering item 1 one way makes item 2 moot,
item 2 is a line in item 1's brief.

## Ranking

Rank by consequence, and tag each line so the ranking is visible. The tags
are exactly these five, optionally followed by a short qualifier after a
colon (`[irreversible: push]`, `[blocking: bug]`):

1. `[irreversible]`: anything that cannot be cleanly undone once acted on,
   or that becomes irreversible by waiting: data deletion, worktree or
   clone deletion, a merge or push to a shared branch, a migration, an
   outward post, a deadline. Deletion is always this tier, however small.
2. `[blocking]`: anything that stops other work, including work an agent is
   waiting on.
3. `[assumption]`: decisions already made by assuming, which are cheap to
   fix now and expensive later.
4. `[follow-up]`: promised but not yet due.
5. `[cosmetic]`: naming, wording, formatting, ordering.

Within a tier, put the one with the widest blast radius (more people, more
systems) first. A group takes the tier of its most consequential sub-item.

## Inventory format

```markdown
Open items (6):

1. [irreversible] Whether to delete the old retention bucket after the
   migration
2. [irreversible] Stale worktrees to delete or keep (3)
3. [blocking] Which repo the alert rule change belongs in
4. [assumption] I assumed the 30-day retention default applies to tracing
5. [follow-up] Update [OBS-869](https://tracker.example.com/issue/OBS-869)
   "retention policy" once
   [observability#2627](https://github.com/example-org/observability/pull/2627)
   "retention policy" merges
6. [cosmetic] Dashboard panel title wording

For the record: the compactor gate passed at 14:02Z; nothing to decide.

Answers are recorded as we go and the work they authorize runs after the
last question unless you say "now"; "skip" defers, "drop" drops, "enough"
stops.

Starting with 1 of 6.
```

The brief for item 1 follows in the same turn, ending with its question.
Each brief's heading carries its place: `### 1 of 6. <label>`.

## Recording answers

One line per answer, in the reply that follows the user's answer, before the
next brief:

```markdown
1. decided: keep the old bucket for 14 days, then delete; queued
```

Then the next item's brief. The line names the outcome in plain words and
one of `queued` (work for Act), `yours` (the user runs it), `noted` (nothing
to run), or `done now` (the user said "now" and it ran in this turn). A
grouped answer is one line per sub-item, or one line when the answer is the
same for all:

```markdown
2. decided: A (delete) for 1 and 3, B (keep) for 2; queued
```

Every item gets an outcome line, including one the assistant drops because
events resolved it ("6. dropped: the PR merged during the huddle") and one
the user answers outside the offered options (record what they said, not the
nearest letter). An input that is not an answer (a shell command, a side
question, a new topic) does not decide the item; the item stays open, and
is never logged as decided.

If a brief's premise turns out to be false after the user answered, re-ask
that item with the corrected brief. Do not apply the nearest reading of the
old answer.

## Pausing

When the user changes topic mid-walk, or a question has waited through more
than one background turn, the huddle pauses instead of interrupting again:

```markdown
Huddle paused at 4 of 9 (1 to 3 decided). Say "huddle" to pick it back up.
```

Said once. After that, status turns carry the pending question in its
short form as their last line (`Still on 4: A, B, or C?`) and nothing more
of the huddle. The tracking surface already holds the rest, so a resume
needs nothing from memory.

## Decision log

At the end of a walkthrough, when the user calls it with "enough", or on a
resume as the compact list:

```markdown
Decision log:

1. decided: keep the old bucket 14 days, then delete; yours to schedule
2. decided: delete worktrees 1 and 3, keep 2; queued
3. decided: alert rule goes in the service repo, not the deploy repo; queued
4. decided: tracing keeps 30 days; assumption confirmed
5. deferred: ticket update waits for the PR to merge
6. dropped: panel title stays as is

Yours: schedule the bucket deletion (1).

Queue, in order: remove the two worktrees (2); move the alert rule and
commit on the current branch (3).

Still to do: 5, after
[observability#2627](https://github.com/example-org/observability/pull/2627)
"retention policy" merges.

Huddle closed.
```

Each line is `<n>. <decided|deferred|dropped>: <outcome in plain words>;
<queued|yours|noted|done now>`. Numbers match the inventory, every item
appears, and an item whose work failed after the decision stays as
`decided; blocked: <why>`. "Yours" lists what the user runs, with the exact
commands when there are any, together; a script handed over this way
validates or dry-runs before it writes anything.
"Queue" is the authorized work in item order, and Act runs it next.
"Still to do" lists the deferred items with what they wait on. The log is
rendered from the tracking surface and the brief headings, not from memory,
and the last line says the huddle is closed.
