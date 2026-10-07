#!/usr/bin/env bash
# selftest.sh -- exercises clean-history.sh against throwaway repos under $TMPDIR:
# squash, restore, refusals, fold, plan, drop, rebase, conflicts, verify.
# Usage: scripts/selftest.sh [path/to/clean-history.sh]
set -u
CH=${1:-$(cd "$(dirname "$0")" && pwd)/clean-history.sh}; ROOT=$TMPDIR/gch-t; rm -rf "$ROOT"; mkdir -p "$ROOT"; pass=0; fail=0
ok(){ pass=$((pass+1)); echo "PASS: $*"; }; bad(){ fail=$((fail+1)); echo "FAIL: $*"; }
mk(){ local d=$ROOT/$1; mkdir -p "$d"; git init -q --bare "$d/remote.git"; git clone -q "$d/remote.git" "$d/repo" 2>/dev/null; cd "$d/repo" || exit 9
  git config commit.gpgsign false; git config user.name T; git config user.email t@e.com
  git switch -qc main 2>/dev/null || git checkout -qb main
  echo base > a.txt; git add a.txt; git commit -qm "chore: base"; git push -qu origin main 2>/dev/null
  git switch -qc feat
  echo one > b.txt; git add b.txt; git commit -qm "feat(b): add b"
  echo two > c.txt; git add c.txt; git commit -qm "feat(c): add c"
  echo one-fix > b.txt; git add b.txt; git commit -qm "fix b typo"
  echo doc > d.md; git add d.md; git commit -qm "docs: add d"
  echo two-fix > c.txt; git add c.txt; git commit -qm "wip fix c"
  [ "${2:-}" = conflict ] && { echo feat-a > a.txt; git add a.txt; git commit -qm "feat(a): touch a"; }
  git push -qu origin feat 2>/dev/null
  git switch -q main; echo base2 > a.txt; git commit -qam "chore: main moves on"; git push -q origin main 2>/dev/null; git switch -q feat; git fetch -q origin; }
sha(){ git log --format=%h --grep="$1" feat; }

echo "### status"; mk status
if "$CH" status > "$ROOT/status.log" 2>&1 && grep -q 'commits on branch: 5' "$ROOT/status.log" && grep -q 'work tree clean' "$ROOT/status.log" && grep -q 'need --force-with-lease' "$ROOT/status.log"; then ok "status facts + lease warning"; else bad "status"; cat "$ROOT/status.log"; fi

echo "### squash + restore + refusals"; mk squash; tip=$(git rev-parse HEAD)
printf 'feat(bc): add b and c with docs\n\nWhy this exists, in prose.\n\nAssisted-by: Claude Code:test <noreply@anthropic.com>\n' > "$ROOT/msg.txt"
if "$CH" squash --base origin/main --message-file "$ROOT/msg.txt" > "$ROOT/squash.log" 2>&1; then
  [ "$(git rev-list --count origin/main..HEAD)" = 1 ] && ok "squash -> 1 commit" || bad "squash count"
  git diff --quiet "$tip" HEAD && ok "squash tree identical" || bad "squash tree differs"
  grep -q 'tree identical to.*: yes' "$ROOT/squash.log" && ok "squash prints verify" || bad "squash verify line"
  grep -q -- '--force-with-lease=feat:' "$ROOT/squash.log" && ok "squash prints lease push" || bad "lease push line"
  [ -z "$(git status --porcelain)" ] && ok "squash leaves clean tree" || bad "squash dirty"
  bk=$(git for-each-ref --format='%(refname)' refs/backup/feat/ | head -1)
  [ -n "$bk" ] && [ "$(git rev-parse "$bk")" = "$tip" ] && ok "backup ref -> old tip" || bad "backup ref"
else bad "squash exit $?"; cat "$ROOT/squash.log"; fi
if "$CH" restore "$bk" > "$ROOT/restore.log" 2>&1 && [ "$(git rev-parse HEAD)" = "$tip" ] && [ -z "$(git status --porcelain)" ]; then ok "restore to backup"; else bad "restore"; cat "$ROOT/restore.log"; fi
printf 'no conventional subject here\n\nbody\n' > "$ROOT/bad.txt"
"$CH" squash --base origin/main --message-file "$ROOT/bad.txt" > "$ROOT/bad.log" 2>&1; rc=$?
[ $rc -eq 1 ] && [ "$(git rev-parse HEAD)" = "$tip" ] && ok "bad subject refused (rc=1)" || { bad "bad subject rc=$rc"; cat "$ROOT/bad.log"; }
printf 'fix(x): ok subject\nno blank line\n' > "$ROOT/bad2.txt"; "$CH" squash --base origin/main --message-file "$ROOT/bad2.txt" >/dev/null 2>&1; [ $? -eq 1 ] && ok "missing blank line refused" || bad "blank line"
echo x >> b.txt; "$CH" squash --base origin/main --message-file "$ROOT/msg.txt" > "$ROOT/dirty.log" 2>&1; rc=$?; git restore b.txt
[ $rc -eq 1 ] && grep -q 'dirty' "$ROOT/dirty.log" && ok "dirty tree refused" || bad "dirty rc=$rc"

echo "### fold (autosquash)"; mk fold; t=$(sha 'fix b typo'); echo one-fix2 > b.txt; git add b.txt; git commit -q --fixup="$t"; tip=$(git rev-parse HEAD)
if "$CH" fold --base origin/main > "$ROOT/fold.log" 2>&1; then
  [ "$(git rev-list --count origin/main..HEAD)" = 5 ] && ok "fold 6 -> 5 commits" || bad "fold count"
  git diff --quiet "$tip" HEAD && ok "fold tree identical" || bad "fold tree"
  ! git log --format=%s origin/main..HEAD | grep -q '^fixup!' && ok "fixup absorbed" || bad "fixup remains"
  grep -q 'range-diff' "$ROOT/fold.log" && ok "fold prints range-diff" || bad "no range-diff"
else bad "fold exit $?"; cat "$ROOT/fold.log"; fi
"$CH" fold --base origin/main > "$ROOT/fold2.log" 2>&1; [ $? -eq 1 ] && grep -q 'no fixup' "$ROOT/fold2.log" && ok "fold without fixups refused" || bad "fold2"

echo "### fold conflict -> restore"; mk foldc; t=$(sha 'feat(b)'); echo clash > b.txt; git add b.txt; git commit -q --fixup="$t"; tip=$(git rev-parse HEAD)
"$CH" fold --base origin/main > "$ROOT/foldc.log" 2>&1; rc=$?
[ $rc -eq 2 ] && grep -q 'b.txt' "$ROOT/foldc.log" && ok "fold conflict rc=2 lists file" || { bad "foldc rc=$rc"; cat "$ROOT/foldc.log"; }
bk=$(git for-each-ref --format='%(refname)' refs/backup/feat/ | head -1)
if "$CH" restore "$bk" > "$ROOT/foldr.log" 2>&1 && [ "$(git rev-parse HEAD)" = "$tip" ] && [ -z "$(git status --porcelain)" ] && [ ! -d .git/rebase-merge ]; then ok "restore aborts mid-rebase"; else bad "restore mid-rebase"; cat "$ROOT/foldr.log"; fi

echo "### plan + fold --plan"; mk plan; tip=$(git rev-parse HEAD)
"$CH" plan --base origin/main --out "$ROOT/plan.txt" >/dev/null 2>&1 && [ "$(grep -c '^pick' "$ROOT/plan.txt")" = 5 ] && ok "plan has 5 picks" || bad "plan"
b=$(sha 'feat(b)'); c=$(sha 'feat(c)'); fb=$(sha 'fix b typo'); fc=$(sha 'wip fix c'); d=$(sha 'docs: add d')
printf 'pick %s\nfixup %s\npick %s\nfixup %s\npick %s\n' "$b" "$fb" "$c" "$fc" "$d" > "$ROOT/plan2.txt"
if "$CH" fold --base origin/main --plan "$ROOT/plan2.txt" > "$ROOT/planfold.log" 2>&1; then
  [ "$(git rev-list --count origin/main..HEAD)" = 3 ] && ok "plan fold 5 -> 3" || bad "plan count $(git rev-list --count origin/main..HEAD)"
  git diff --quiet "$tip" HEAD && ok "plan fold tree identical" || bad "plan tree"
else bad "plan fold exit $?"; cat "$ROOT/planfold.log"; fi
printf 'pick %s\nsquash %s\n' "$b" "$fb" > "$ROOT/badplan.txt"; "$CH" fold --base origin/main --plan "$ROOT/badplan.txt" >/dev/null 2>&1; [ $? -eq 1 ] && ok "squash verb rejected" || bad "squash verb"
mk plan2; b=$(sha 'feat(b)'); c=$(sha 'feat(c)'); printf 'pick %s\npick %s\n' "$b" "$c" > "$ROOT/omit.txt"; tip=$(git rev-parse HEAD)
"$CH" fold --base origin/main --plan "$ROOT/omit.txt" > "$ROOT/omit.log" 2>&1; rc=$?
[ $rc -eq 1 ] && grep -q 'plan omits' "$ROOT/omit.log" && [ "$(git rev-parse HEAD)" = "$tip" ] && [ ! -d .git/rebase-merge ] && ok "omitted lines refused before touching history" || { bad "omit rc=$rc"; cat "$ROOT/omit.log"; }
mk plan3; b=$(sha 'feat(b)'); c=$(sha 'feat(c)'); fb=$(sha 'fix b typo'); fc=$(sha 'wip fix c'); d=$(sha 'docs: add d'); tip=$(git rev-parse HEAD)
printf 'pick %s\nfixup %s\npick %s\nfixup %s\ndrop %s\n' "$b" "$fb" "$c" "$fc" "$d" > "$ROOT/drop.txt"
if "$CH" fold --base origin/main --plan "$ROOT/drop.txt" > "$ROOT/drop.log" 2>&1; then
  [ "$(git rev-list --count origin/main..HEAD)" = 2 ] && ! git cat-file -e HEAD:d.md 2>/dev/null && grep -q 'differs by design' "$ROOT/drop.log" && ok "drop plan -> 2 commits, d.md gone, diff reported" || { bad "drop content"; cat "$ROOT/drop.log"; }
else bad "drop exit $?"; cat "$ROOT/drop.log"; fi

echo "### rebase (clean)"; mk rb; tip=$(git rev-parse HEAD)
if "$CH" rebase --onto origin/main > "$ROOT/rb.log" 2>&1; then
  [ "$(git merge-base origin/main HEAD)" = "$(git rev-parse origin/main)" ] && ok "rebased onto origin/main" || bad "rebase base"
  grep -q 'commit count unchanged: 5' "$ROOT/rb.log" && ok "rebase count unchanged" || bad "rebase count"
  grep -q 'branch diff relative to base unchanged: yes' "$ROOT/rb.log" && ok "rebase diff unchanged" || bad "rebase diff"
else bad "rebase exit $?"; cat "$ROOT/rb.log"; fi
"$CH" rebase --onto origin/main > "$ROOT/rb2.log" 2>&1; [ $? -eq 1 ] && grep -q 'already based' "$ROOT/rb2.log" && ok "rebase no-op refused" || bad "rebase no-op"

echo "### rebase (conflict) -> continue -> verify"; mk rbc conflict; tip=$(git rev-parse HEAD)
"$CH" rebase --onto origin/main > "$ROOT/rbc.log" 2>&1; rc=$?
[ $rc -eq 2 ] && grep -q '  a.txt' "$ROOT/rbc.log" && ok "rebase conflict rc=2 lists a.txt" || { bad "rbc rc=$rc"; cat "$ROOT/rbc.log"; }
echo resolved > a.txt; git add a.txt; git rebase --continue >/dev/null 2>&1
if "$CH" verify > "$ROOT/rbv.log" 2>&1; then grep -q 'branch diff relative to base changed' "$ROOT/rbv.log" && grep -q -- '--force-with-lease=feat:' "$ROOT/rbv.log" && ok "verify after continue reports + lease" || { bad "verify content"; cat "$ROOT/rbv.log"; }; else bad "verify exit $?"; cat "$ROOT/rbv.log"; fi

echo "### verify with no state"; mk v; "$CH" verify > "$ROOT/v.log" 2>&1; [ $? -eq 1 ] && grep -q 'no previous run' "$ROOT/v.log" && ok "verify without state refused" || bad "verify nostate"

echo; echo "RESULT: pass=$pass fail=$fail"
