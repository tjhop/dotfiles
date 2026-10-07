# Decision brief template

One brief per item, under 250 words. Every section is present; write
"unknown" or "none" rather than dropping one, so a missing fact is visible
instead of silently absent. When the brief will not fit, cut evidence, not
options or the question. Nothing else shares the turn with a brief except the
one-line record of the previous answer.

## Single item

```markdown
### <n> of <M>. <plain-words label>

**What:** <one line: the decision to make, not the background>

**Why it matters now:** <one or two lines: what is blocked, what gets worse,
or what deadline applies if this waits>

**Context and evidence:**
1. <fact> (<source: file:line, [repo#PR](pr url) "title",
   [TICKET](ticket url) "title", log line, query and value>)
2. <fact> (<source>)
3. Unknown: <what you could not establish, and the read-only lookup that
   would settle it>

**Options:**
- **A. <plain-words name>**: <what it means>; <trade-off in one line>
- **B. <plain-words name>**: <what it means>; <trade-off in one line>
- **C. <plain-words name>** (optional, up to four): ...

**Recommendation:** <option>, confidence <n>/10. Would change if <the one
fact or event that would flip it>.

**Reversibility and blast radius:** <what can be undone and how; what
cannot; who else or what else is affected>

**Question:** <one sentence naming the concrete choices: "A, B, or C?">
```

## Grouped item

For two to five sub-items that take the same options. The shared sections
are written once; each sub-item gets one evidence line and one recommended
letter.

```markdown
### <n> of <M>. <plain-words label for the group> (<k> items)

**What:** <one line: the decision, applied to each item below>

**Why it matters now:** <one or two lines, shared>

**Items:**
1. <sub-item>: <its one line of evidence with source>
2. <sub-item>: <its one line of evidence with source>
3. <sub-item>: <its one line of evidence with source>

**Options (per item):**
- **A. <plain-words name>**: <what it means>; <trade-off>
- **B. <plain-words name>**: <what it means>; <trade-off>
- **C. <plain-words name>**: <what it means>; <trade-off>

**Recommendation:** A for 1 and 3, B for 2, confidence <n>/10. Would change
if <...>.

**Reversibility and blast radius:** <shared; name any sub-item that differs>

**Question:** A, B, or C for each? ("C for all" or "A for 1 and 3, B for 2"
both work.)
```

Inside a grouped brief, bare numbers in the answer mean the sub-items. If the
user answers only some ("A for 1"), the next line asks for the rest by
number, without reprinting the brief.

## Writing notes

- Evidence is numbered so the user can answer "what's the source for 2?"
  without re-reading. Three facts is the default; more only when the choice
  turns on them. Quote short source text when wording matters; do not
  upgrade "might" in a source to "will" in the brief.
- Options are real alternatives the user could pick, including "wait" or
  "do nothing" when that is genuinely on the table. Two well-separated
  options beat four overlapping ones.
- Option names are plain words. A spec section, step label, ruling id, or
  internal code goes in parentheses after the words ("sign the amendment as
  written (4c)"), never as the name itself.
- When an option has the user doing something, the option line carries the
  exact command or link, so "how do I do A?" never needs a second turn.
- When an option is an outward write (a ticket comment, a PR comment, a
  post), the brief shows the exact text that would go out. Choosing that
  option authorizes the write in Act; without the text shown, the item is
  queued as a draft for the user's "post".
- The confidence is yours, stated plainly. A 5/10 recommendation is fine
  and useful; it tells the user the evidence is thin.
- The question is the last line of the turn and the only question in it.
- No status of running work, no progress on other items, no new findings
  in a brief turn. Those go in Act, or in one line of a notification turn.

## Worked example (illustrative)

The situation below is invented to show the shape. It is not a real
incident, and the component names, counts, and timelines are placeholders,
not facts about any cluster or ticket.

```markdown
### 1 of 6. Pin the ingester StatefulSet or wait for the autoscaler fix

**What:** Choose between pinning the ingester StatefulSet's replica count
by hand and waiting for the cluster autoscaler fix to land.

**Why it matters now:** Ingesters are being evicted during scale-down, and
each eviction causes a short write gap in the metrics pipeline. The next
scale-down window is tonight.

**Context and evidence:**
1. The ingester pods were evicted twice in the last day, each time during
   a node scale-down (from `kubectl get events` on the namespace).
2. The StatefulSet has no PodDisruptionBudget (from its manifest in the
   gitops repo).
3. Unknown: whether the write gaps lost data or only delayed it. A query
   for dropped samples over the eviction windows would settle it.

**Options:**
- **A. Pin replicas and add a PDB**: stops the evictions today; adds a
  manual override someone has to remember to remove.
- **B. Add only a PDB**: smaller change, keeps autoscaling; may block
  scale-down entirely if the budget is too strict.
- **C. Wait for the fix**: no new config; evictions continue until it
  ships, on an unknown date.

**Recommendation:** B, confidence 6/10. Would change to A if the
dropped-samples query shows real data loss rather than delay.

**Reversibility and blast radius:** A and B are a single revert in the
gitops repo. B can stall node scale-down for the whole node pool, which
affects other teams' workloads. C is free to reverse but costs more gaps.

**Question:** A (pin and PDB), B (PDB only), or C (wait for the fix)?
```

That brief is about 240 words including the headings. The grouped shape
for the same session might be:

```markdown
### 2 of 6. Stale worktrees to delete or keep (3 items)

**What:** For each worktree left from merged work, delete it, keep it, or
leave it to you.

**Why it matters now:** They hold about 1.2 GB and two of them pin
branches that the next sweep would otherwise prune.

**Items:**
1. `ingester-pin`: branch merged in
   [observability#2589](https://github.com/example-org/observability/pull/2589)
   "pin ingesters to 20", tree clean (`git status` in the worktree).
2. `build-key-default`: branch has two unpushed commits (`git log
   origin/main..HEAD`).
3. `runbook-notes`: branch merged, tree has an untracked notes file.

**Options (per item):**
- **A. Delete**: frees the space; unrecoverable once the branch is pruned.
- **B. Keep**: nothing changes; the sweep keeps flagging it.
- **C. Yours**: I leave it and list it under "Yours" with the remove
  command.

**Recommendation:** A for 1, B for 2 (unpushed commits), C for 3 (the
notes file is yours to judge), confidence 8/10. Would change to A for 3
if the notes file is scratch.

**Reversibility and blast radius:** A is irreversible for the worktree;
the merged commits stay on main. B and C change nothing. Only this
machine is affected.

**Question:** A, B, or C for each? ("A for all" or "A for 1, B for 2, C
for 3" both work.)
```
