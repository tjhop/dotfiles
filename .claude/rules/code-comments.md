# Code comments

Comments describe the code as it is, never its history or its ticket.

- No ticket, issue, or PR numbers in code comments. Put those references in
  the commit message, where `git log` and `git blame` can find them.
- No time- or state-relative wording such as "currently", "recently", "as of",
  "for now", or "was previously"; those descriptions go stale.
- Never derive a comment from a tunable value; the value and the comment drift.
- Put the reasoning behind a change in the commit body. A comment earns its
  place when it explains something the code itself cannot say.
- Prefer no comment over one that restates the code.

Why: Nine corrections in the mined history asked for changes such as "remove ticket references from code comments, trim/condense them".
