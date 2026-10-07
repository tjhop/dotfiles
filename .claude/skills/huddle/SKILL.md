---
name: huddle
description: Pause the work and give the user the context to decide - either inventory everything open in this session and walk through it one decision at a time, or write one short decision brief (what, why now, evidence with sources, options with trade-offs, a recommendation with confidence, reversibility, one question) for a single item. Questions are asked early and in one run, and the work they authorize follows, so the user is interrupted once and is then free to do something else while it runs. Use this whenever the user types /huddle (bare, with a number, or with a topic), or says "walk me through what's open", "what do you need from me", "what's waiting on me", "what's left", "where are we", "let's go through these one at a time", "let's go through these individually", "can you elaborate a bit?", "give me details instead of ticket references", "I need more context before I pick", "give me more context on X before I decide", or "elaborate on option 2" - and for looser forms like "hang on, context first", "before I answer, what are the options", "walk me through it", "one at a time please", "slow down, what's still open", "sorry, let's try again", "anything else needed from me?", or "what are you waiting on from me", even without a slash and even when no item is named.
---

# Huddle

## Purpose

The user often stops a task to ask for more detail before deciding, or to go
through open questions individually. Without a fixed shape, the answer comes
back as one wall of text covering every question at once, or the open
questions get quietly resolved by assumption, and the user has to re-ask. A
huddle makes the open items explicit, takes them one at a time, and gives each
one just enough evidence to decide on.

A huddle has three phases, and keeping them apart is most of the skill:

1. **Stage**: find every open item, group the ones that need the same kind
   of decision, gather the evidence for all of them, and write the list down.
2. **Decide**: one question per turn; answer, record, next question. Nothing
   happens between answers except writing the decision down.
3. **Act**: after the last answer, print the decision log and do the work
   the answers authorized, in order.

The reason for the split is to ask everything early and ask it once. Every
question the user has to come back for is an interrupt and a context switch
away from whatever else they are doing. A run of questions with nothing in
between is answered in one pass, and the work that follows needs nothing
more from them, so they are free to turn to something else while it runs.

There is no script. Finding open items and weighing them is judgment over
the conversation, so all of it is yours.

## Pick the shape from the argument

| The ask sounds like | Shape |
|---|---|
| `/huddle`, "walk me through what's open", "what do you need from me", "one at a time please", "let's go through these individually" | **walkthrough**: Stage, Decide, Act |
| `/huddle`, "what's waiting on me", "what's left", "anything else from me?", "let's try again" while a walkthrough from earlier in the session is unfinished | **resume** that walkthrough; do not start a new inventory |
| `/huddle 2`, "elaborate on option 2", "more on the second one" | **single brief** for item 2 of the most recent numbered list in the session |
| `/huddle <topic>`, "give me more context on the retention change before I decide" | **single brief** for the item matching the topic; when the topic matches several open items ("huddle on the gateway PR"), a **walkthrough scoped to the topic** |
| "I need more details before deciding" with nothing named | **single brief** if exactly one decision is pending; otherwise the walkthrough |

A number refers to the last numbered list you showed the user (an inventory,
a list of options, a list of questions). If two recent lists could match, say
which one you took in a line before the brief. A topic that matches nothing
open gets a one-line "nothing open on that" plus the inventory, not an
invented decision.

## Stage

Read back through the session and collect every open item. Where they hide
is in `references/walkthrough.md`; the short list:

- questions you asked that the user has not answered;
- decisions you deferred, or made by assuming ("assuming", "I'll proceed
  with", "for now I went with");
- blocked or unfinished tasks, including checks that failed and were left;
- assumptions stated but never verified;
- follow-ups you promised ("I'll check X after", "TODO (@claude)").

When this session is a background job that reports with `needs input:`
lines, its pending lines are the inventory; add nothing else unless it is
clearly open too.

Then, before showing anything:

1. **Drop what needs no decision.** Check the session's decision record
   first: an item it already shows as decided is not open, and a standing
   decision is re-asked only when a new fact has arrived. An item that is
   information only, or where the only honest option is "nothing to decide
   today", or that is not ready to decide yet, is not an item either. Each
   goes in one line under "For the record" at the end of the inventory, not
   in a brief. Items decided in an earlier huddle that only await the
   user's "post" or "push" are one grouped item with the options run or
   hold.
2. **Group.** Items that need the same kind of decision with the same option
   set (three stale worktrees to delete or keep, four tickets to reopen or
   leave closed, two config scripts to approve) become one grouped item with
   numbered sub-items. Up to five per group; split a longer run in two. Items
   whose options differ stay separate even when the topic is the same. The
   rule is in `references/walkthrough.md` under "Grouping".
3. **Rank and tag.** Irreversible first, then blocking, then everything
   else, and number the items. A group takes one number. The tags are
   exactly `[irreversible]`, `[blocking]`, `[assumption]`, `[follow-up]`,
   `[cosmetic]`, with an optional short qualifier after a colon; no others,
   and deletion of anything is always `[irreversible]`.
4. **Gather evidence for every item now**, not one item at a time later.
   Read-only lookups only: files, `git log`, PR and ticket reads (`gh pr
   view`, the tracker's issue lookup), metric and log queries. Batch them. After this step a Decide
   turn needs no tool calls except writing the decision down.
5. **Write the inventory to the tracking surface** (below), so it survives
   context compaction and a later resume.

The first turn then shows: the numbered inventory, one line per item (number,
tag, plain-words label, sub-count for a group), the "For the record" lines
if any, one protocol sentence, the brief for item 1 headed `1 of M`, and
item 1's question as the last line. The protocol sentence: answers are
recorded as you go and the work they authorize runs after the last question
unless you say "now"; "skip" defers, "drop" drops, "enough" stops. If
nothing is open, say so in one line and stop.

## Decision brief

Use the template in `references/brief-template.md`. Sections, in order:

1. **What**: one line.
2. **Why it matters now**: one or two lines.
3. **Context and evidence**: up to three facts with their sources
   (`file:line`, PR as a link with repo and title, ticket as a link with its
   title, log line, metric query and value). Number them; never paraphrase a
   source into a stronger claim than it makes. Say "unknown" where you do
   not know. More than three only when the choice turns on them.
4. **Options**: two to four, each with its trade-off in one line. Names in
   plain words; an internal code, spec section, or step label goes in
   parentheses after the words, never instead of them. If an option has the
   user doing something, the option line carries the exact command or link.
5. **Recommendation**: the option, a confidence (for example "7/10"), and
   the one thing that would change it.
6. **Reversibility and blast radius**: what can be undone, what cannot, who
   else is affected.
7. **The question**: one sentence that names the concrete choices.

A grouped item uses the grouped form of the template: one What and Why, the
numbered sub-items with their one-line evidence, one shared option set, a
recommendation per sub-item or "A for all", and a question that invites
"C for all" or "A for 1 and 3, B for 2".

A brief is under 250 words, and the user may ask for more with "more" or
"elaborate", which expands it in the next turn. Nothing else goes in a brief
turn: no status of running work, no progress report, no second item. If a
brief will not fit, the evidence is what gets cut, not the options or the
question.

## Decide

1. The first turn ends with item 1's question. One question per turn, always
   the last line.
2. On the user's answer, echo it in one line (`1. decided: pin replicas to
   3`), write it to the tracking surface, and give the next brief in the
   same turn. Every answer is echoed, including the last one and one that
   arrived while you were mid-turn (quote it: `taking "go ahead with a" as
   item 3`). The answer alone advances; the user does not have to say
   "next". "Your call", "go with your recommendation", or "recs for the
   rest" records the recommendation as the decision, marked as such.
3. Work the answer implies is **queued, not done**: "go ahead", "yes, do
   it", "cut the PR" record the item as decided and authorized, and the work
   runs in Act. Only "now", "before we go on", or "do it before the next one"
   runs it in this turn, and then one line says what was done. Writing the
   decision down (decision log, ledger, spec notes, memory) is not work; do
   it every time. Scripts or commands the user is to run are handed over in
   Act, together, not mid-walk; an option is "yours" only when you cannot
   run it yourself. Background work the user asked for, or that was already
   running, carries on; it reports in one line per notification turn.
4. "skip", "later", or "not now" records the item as `deferred`. "drop it",
   "never mind" records it as `dropped`. Either way, move to the next item.
   An input that is not an answer (a shell command, a side question, a new
   topic) decides nothing: the item stays open and is never logged as
   decided. A side question becomes a new numbered item, not an "if you
   want it, say so" offer. A topic change pauses the huddle in one line
   (`references/walkthrough.md`, "Pausing") and follows the new topic.
5. A grouped answer ("C for all", "A for 1 and 3, B for 2", "skip the rest")
   is recorded per sub-item. A partial answer ("A for 1") leaves the other
   sub-items open; ask for only those in one line, not the whole brief again.
   Inside a grouped brief, bare numbers in the answer are the sub-items;
   jumping to another inventory item is "item 7" or "do 7 next".
6. Numbers are stable for the whole walkthrough. New items that surface
   mid-walk are appended at the end with the next number, not re-ranked in
   and not taken next. One may jump the queue only when it blocks the item
   on the table; say so in a line and close the current question first.
7. The user may jump ("do 4 next", "back to 2"); follow, keeping the numbers.
8. A background notification (a task finishing, a poller result, a bash
   result) arriving mid-huddle is not a huddle turn. Handle it in one or two
   lines, do not reprint the brief, and end with the pending question in its
   short form: `Still on 6: A, B, or C?`. If the notification changes the
   facts for the pending item, say so in one line and restate only the
   options. The same goes for a turn the session takes on its own in an
   autonomous job: one line of status, then the short-form question. After
   the first such turn with no answer, say once that the huddle is paused
   at `N of M`; do not re-ask in full again until the user is back.
9. "enough", "that's all for now", or "skip the rest" ends Decide early: the
   remaining items are recorded as `deferred` and the huddle moves to Act.
10. The reply to the last answer is its echo followed by the decision log.
    Never end a walkthrough silently. Every item gets an outcome line,
    including one that events resolved mid-walk and one the user answered
    outside the offered letters; record what they said, not the nearest
    letter. If a brief's premise turns out false after the answer, re-ask
    that item with the corrected brief instead of reading the old answer
    onto the new facts.

A single-brief huddle ends with the brief's question. Once the user answers,
record the decision in one line and go back to what you were doing.

## Act

When every item is decided, deferred, or dropped:

1. Print the decision log from `references/walkthrough.md`, rendered from
   the tracking surface and the brief headings, not from memory: one line
   per item with its outcome, then "Yours" for anything the user runs (the
   exact commands, together, each validated or dry-run before it writes),
   then the queue of authorized work in item order, then "Still to do" for
   deferred items.
2. Do the queued work in that order. One line per item as it completes,
   with the usual evidence (commit, PR link with title, file). An outward
   write runs here only if its brief showed the exact text and the user
   chose that option; otherwise it is a draft waiting for "post". If an
   item fails or needs a new decision, say so in one line and continue with
   the rest; the new decision is appended to the inventory with the next
   number.
3. If anything was appended during Act, those items are open: brief the
   first one and run a short Decide for them, then a short Act. Nothing is
   left half-asked.
4. Stop. Do not open a new inventory unless asked.

## Resume

A walkthrough is unfinished while any item is still open. When the user says
`/huddle`, "what's waiting on me", "what's left", "anything else from me?",
or "sorry, let's try again" and one is unfinished, including after a context
compaction:

1. Read the tracking surface, not your memory of the conversation and not
   the compaction summary.
2. Show the compact list: every item with its status (`decided: ...`,
   `deferred`, `dropped`, `open`), same numbers as before.
3. Continue from the first open item with its brief and question. Re-check
   the "why it matters now" facts of each open item before re-asking; a
   compaction summary can carry an item as pending after the session has
   already resolved it.
4. Items that became open since the inventory are appended with the next
   number; items the user resolved outside the huddle are marked from what
   the session shows, in one line each.

Do not restart the inventory from scratch while one is unfinished. A new
inventory only starts when the previous walkthrough reached Act, or the user
says "start over".

## Tracking surface

Every inventory line and every recorded answer is written, in the turn it
happens, to the place this session already tracks decisions: the job's own
state files in a background job, the ledger or spec notes a long-running
session keeps, a design document the
work is for, or memory when the decision is one to keep. If the session has
none of these, keep a `huddle.md` in the session's temp directory with the
inventory, the status of each item, and the queue. This is the one write a
Decide turn always makes, and it is what Resume and the decision log read.

## Guardrails

- One question per turn. A brief ends with exactly one question; never stack
  a second one under it. A grouped brief's single question covers all its
  sub-items.
- Nothing between answers. Writing the decision down is not work; anything
  that changes a file, a ticket, a PR, a running process, or a schedule is,
  and it waits for Act unless the user says "now".
- Never resolve an item by assuming while in a huddle. If you cannot decide
  without the user, the item stays open until the user answers. Recording
  "assumed A" before the answer arrives is resolving by assuming.
- No bare ticket ids or PR numbers, anywhere in the turn: inventory lines,
  briefs, option lines, the question line, status updates and decision log
  alike. Every ticket is a link on its id with its title
  (`[OBS-869](https://tracker.example.com/issue/OBS-869) "retention policy"`),
  every PR a link on `repo#number` with its title
  (`[observability#2627](https://github.com/example-org/observability/pull/2627) "retention policy"`).
  Titles come from a read this session, not from memory. This is the "give
  me details instead of ticket references" complaint, and the git context
  rule says the same.
- Plain words before codes. An option or item named only by an internal
  label ("F4", "4b", "chunk 2a") is unreadable to someone who has not got
  the spec open; say what it is first, then the code.
- Read-only during Stage and Decide. No ticket, PR, or chat writes, no
  pushes, no destructive commands until Act, and then only what an answer
  authorized.
- When a decision is later written into a ticket or PR comment, follow the
  `outward-writes` rule: no local paths, session ids, or agent details in
  the posted text, and only post when the user asked for the post.
- Evidence beats recall. If a fact can be checked in a few read-only
  commands, check it in Stage before putting it in a brief, and cite where
  it came from.
