#!/usr/bin/env bash
# clean-history.sh -- deterministic local history rewriting for one branch.
#
#   status   [--base <ref>]                         preflight facts; changes nothing
#   plan     [--base <ref>] --out <file>            write an editable rebase todo
#   squash   [--base <ref>] --message-file <file>   collapse base..HEAD into one commit
#   fold     [--base <ref>] [--plan <file>]         apply fixup!/amend! commits, or a todo plan
#   rebase   --onto <ref> [--no-fetch]              rebase base..HEAD onto <ref>
#   verify   [--old <sha> --base <sha>]             re-run the post-checks (defaults: last run)
#   restore  <backup-ref>                           move the branch back to a backup
#
# Every mutating subcommand runs preflight -> backup ref -> apply -> verify ->
# report. The porcelain commands (reset --soft, commit, rebase) are used on
# purpose: they honour commit.gpgsign, --signoff, and hooks. Plumbing such as
# commit-tree/update-ref skips all three and has produced unsigned commits.
# Nothing here calls git stash, git reset --hard, or git push.
#
# Exit codes: 0 ok; 1 refused or failed before touching history; 2 rebase
# stopped on conflicts (branch is mid-rebase); 3 verification failed.

set -euo pipefail

SELF=$0

die()  { printf 'clean-history: %s\n' "$*" >&2; exit 1; }
note() { printf -- '-- %s\n' "$*"; }

need_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git work tree"
  TOP=$(git rev-parse --show-toplevel)
  GIT_DIR_PATH=$(git rev-parse --git-dir)
  BRANCH=$(git branch --show-current)
  [ -n "$BRANCH" ] || die "detached HEAD; check out the branch you want to rewrite"
  STATE="$GIT_DIR_PATH/clean-history.state"
}

in_rebase() { [ -d "$GIT_DIR_PATH/rebase-merge" ] || [ -d "$GIT_DIR_PATH/rebase-apply" ]; }
dirty()     { [ -n "$(git status --porcelain)" ]; }

# BASE is the merge-base of HEAD and <ref>. Without <ref>, the first of
# origin/main, origin/master, main, master that exists is used.
resolve_base() {
  local ref=${1:-} cand
  if [ -z "$ref" ]; then
    for cand in origin/main origin/master main master; do
      if git rev-parse --verify --quiet "$cand^{commit}" >/dev/null; then ref=$cand; break; fi
    done
    [ -n "$ref" ] || die "cannot infer a base branch; pass --base <ref>"
  fi
  git rev-parse --verify --quiet "$ref^{commit}" >/dev/null || die "base ref '$ref' does not resolve"
  BASE_REF=$ref
  BASE=$(git merge-base "$ref" HEAD) || die "no merge base between $ref and HEAD"
}

preflight() {
  need_repo
  resolve_base "${1:-}"
  OLD=$(git rev-parse HEAD)
  in_rebase && die "a rebase is in progress; run 'git rebase --continue' or 'git rebase --abort' first"
  dirty && die "work tree is dirty; commit first (a WIP or fixup! commit is fine) -- stash is off-limits"
  [ "$BASE" != "$OLD" ] || die "nothing between $BASE_REF and HEAD"
  COUNT=$(git rev-list --count "$BASE..HEAD")
}

backup() {
  BACKUP="refs/backup/$BRANCH/$(date -u +%Y%m%dT%H%M%SZ)"
  git update-ref -m "clean-history: before $1" "$BACKUP" "$OLD"
  note "backup ref $BACKUP -> ${OLD:0:12}"
}

save_state() {  # $1 mode, $2 new base
  printf 'MODE=%s\nOLD=%s\nBASE=%s\nNEWBASE=%s\nBACKUP=%s\n' "$1" "$OLD" "$BASE" "$2" "$BACKUP" > "$STATE"
}

gpgsign_wanted() { [ "$(git config --type=bool --get commit.gpgsign 2>/dev/null || echo false)" = true ]; }
is_signed()      { git cat-file commit "$1" | grep -q '^gpgsig'; }
signoff_used()   { git log --format=%B "$1..$2" | grep -q '^Signed-off-by:'; }

# The subject line is what `git log --oneline` and PR titles show; the body is
# where the reasoning lives. Refuse messages that would fail either job.
check_message() {
  local f=$1 subj
  [ -s "$f" ] || die "--message-file must name a non-empty file"
  subj=$(sed -n '1p' "$f")
  printf '%s' "$subj" | grep -Eq '^[a-z]+(\([^)]+\))?!?: [^ ]' \
    || die "subject must follow Conventional Commits (type(scope): summary); got: $subj"
  [ "${#subj}" -le 72 ] || die "subject is ${#subj} chars; keep it at most 72"
  [ -z "$(sed -n '2p' "$f")" ] || die "line 2 of the message must be blank"
  sed -n '3,$p' "$f" | grep -q '[^[:space:]]' || die "message needs a body: what changed and why"
}

# verify <mode> <old> <base-for-old> <base-for-new>
#   tree   : new HEAD must have exactly the old tree (squash/fold)
#   rebase : same commit count expected; branch diff compared, differences reported
verify() {
  local mode=$1 old=$2 obase=$3 nbase=$4 new fail=0 c unsigned=0 nosignoff=0
  new=$(git rev-parse HEAD)
  printf '\n== verify\n'
  if [ "$mode" = tree ]; then
    if git diff --quiet "$old" "$new"; then note "tree identical to ${old:0:12}: yes"
    else note "tree identical to ${old:0:12}: NO"; fail=1; fi
  elif [ "$mode" = drop ]; then
    note "tree differs by design (plan dropped commits); diff against ${old:0:12}:"
    git diff --stat "$old" "$new" | sed 's/^/     /'
  else
    local oc nc
    oc=$(git rev-list --count "$obase..$old"); nc=$(git rev-list --count "$nbase..$new")
    if [ "$oc" -eq "$nc" ]; then note "commit count unchanged: $nc"
    else note "commit count $oc -> $nc (fewer is normal when commits were already upstream)"; fi
    if [ "$(git diff "$obase" "$old" | git patch-id --stable | cut -d' ' -f1)" = \
         "$(git diff "$nbase" "$new" | git patch-id --stable | cut -d' ' -f1)" ]; then
      note "branch diff relative to base unchanged: yes"
    else
      note "branch diff relative to base changed (expected after conflict resolution); review the range-diff"
    fi
  fi
  for c in $(git rev-list "$nbase..$new"); do
    if gpgsign_wanted && ! is_signed "$c"; then unsigned=$((unsigned + 1)); fi
    if signoff_used "$obase" "$old" && ! git log -1 --format=%B "$c" | grep -q '^Signed-off-by:'; then
      nosignoff=$((nosignoff + 1)); fi
  done
  if gpgsign_wanted; then
    if [ "$unsigned" -eq 0 ]; then note "all commits signed: yes"; else note "UNSIGNED commits: $unsigned"; fail=1; fi
  fi
  if signoff_used "$obase" "$old"; then
    if [ "$nosignoff" -eq 0 ]; then note "Signed-off-by carried on every commit: yes"
    else note "commits missing Signed-off-by: $nosignoff"; fail=1; fi
  fi
  if [ "$mode" = rebase ] || [ "$COUNT_HINT" != 1 ]; then
    printf '\n== range-diff (old vs new)\n'
    git range-diff "$obase..$old" "$nbase..$new" || true
  fi
  if [ "$fail" -ne 0 ]; then
    printf '\nverification FAILED; undo with: %s restore %s\n' "$SELF" "${BACKUP:-<backup-ref>}" >&2
    exit 3
  fi
}

report() {  # $1 base for log
  local upstream remote rbranch usha
  printf '\n== result\n**worktree** `%s` -- **branch** `%s`\n\n' "$TOP" "$BRANCH"
  git log --oneline "$1..HEAD"
  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)
  printf '\n'
  if [ -n "$upstream" ]; then
    remote=${upstream%%/*}; rbranch=${upstream#*/}; usha=$(git rev-parse "$upstream")
    if git merge-base --is-ancestor "$usha" HEAD; then
      printf 'push (fast-forward): git push %s %s:%s\n' "$remote" "$BRANCH" "$rbranch"
    else
      printf 'push (history rewritten; lease pinned to the remote tip seen now):\n'
      printf '  git push --force-with-lease=%s:%s %s %s:%s\n' "$rbranch" "${usha:0:12}" "$remote" "$BRANCH" "$rbranch"
    fi
  else
    printf 'no upstream yet: git push -u origin %s\n' "$BRANCH"
  fi
  printf 'undo: %s restore %s\n' "$SELF" "$BACKUP"
}

conflict_exit() {
  printf '\n== rebase stopped on conflicts\n'
  git diff --name-only --diff-filter=U | sed 's/^/  /'
  printf '\nresolve each file, then: git add <file> && git rebase --continue\n'
  printf 'after the rebase finishes:  %s verify\n' "$SELF"
  printf 'to give up:                 git rebase --abort   (branch returns to %s; backup %s)\n' "${OLD:0:12}" "$BACKUP"
  exit 2
}

# ---------------------------------------------------------------- subcommands

cmd_status() {
  local base=''
  while [ $# -gt 0 ]; do case $1 in --base) base=$2; shift 2;; *) die "status: unknown argument $1";; esac; done
  need_repo; resolve_base "$base"
  local head; head=$(git rev-parse HEAD)
  printf '**worktree** `%s` -- **branch** `%s`\n\n' "$TOP" "$BRANCH"
  note "base: $BASE_REF (merge-base ${BASE:0:12})"
  note "commits on branch: $(git rev-list --count "$BASE..HEAD")"
  git log --oneline "$BASE..HEAD" | sed 's/^/     /'
  if in_rebase; then note "rebase IN PROGRESS -- finish or abort before anything else"; fi
  if dirty; then note "work tree DIRTY -- commit before rewriting"; else note "work tree clean"; fi
  if git log --format=%s "$BASE..HEAD" | grep -Eq '^(fixup|squash|amend)! '; then
    note "fixup!/amend! commits present: fold will apply them"; fi
  if gpgsign_wanted; then
    local u=0 c; for c in $(git rev-list "$BASE..HEAD"); do is_signed "$c" || u=$((u + 1)); done
    note "commit.gpgsign=true; unsigned commits in range: $u"
  else note "commit.gpgsign is off; signatures not enforced"; fi
  signoff_used "$BASE" "$head" && note "Signed-off-by in use; squash/fold will carry it"
  local upstream; upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)
  if [ -n "$upstream" ]; then
    # Rewriting base..HEAD replaces any upstream commit inside that range, so
    # what matters is whether the upstream tip sits at or before the base.
    if git merge-base --is-ancestor "$(git rev-parse "$upstream")" "$BASE"; then note "upstream $upstream is at or before the base: plain push after rewrite"
    else note "upstream $upstream holds commits a rewrite will replace: push will need --force-with-lease"; fi
  else note "no upstream configured"; fi
  local b; b=$(git for-each-ref --format='%(refname) %(objectname:short)' "refs/backup/$BRANCH/" | tail -3)
  [ -n "$b" ] && { note "recent backups:"; printf '%s\n' "$b" | sed 's/^/     /'; }
  return 0
}

cmd_plan() {
  local base='' out=''
  while [ $# -gt 0 ]; do case $1 in --base) base=$2; shift 2;; --out) out=$2; shift 2;; *) die "plan: unknown argument $1";; esac; done
  [ -n "$out" ] || die "plan: --out <file> is required"
  preflight "$base"
  {
    git log --reverse --format='pick %h %s' "$BASE..HEAD"
    cat <<'EOF'

# Edit the lines above, then run:  fold --base <ref> --plan <this file>
#   pick <sha>          keep the commit
#   fixup <sha>         meld into the commit above, keep that commit's message
#   fixup -C <sha>      meld into the commit above, use THIS commit's message
#   drop <sha>          delete the commit (omitting a line is an error, not a drop)
# Reorder lines to reorder commits. Avoid squash/reword: no editor opens here,
# so squash concatenates messages and reword keeps the old one. To change a
# message, commit `git commit --fixup=reword:<sha> -F <msg>` and run fold
# without --plan afterwards.
EOF
  } > "$out"
  note "plan written to $out ($COUNT commits from $BASE_REF)"
}

validate_plan() {
  local plan=$1 line verb sha rest n=0 shas='' full found
  while IFS= read -r line || [ -n "$line" ]; do
    case $line in ''|'#'*) continue;; esac
    verb=${line%% *}; rest=${line#* }
    case $verb in
      pick|p|fixup|f|drop|d) ;;
      squash|s|reword|r) die "plan: '$verb' needs an editor and none opens here; use fixup / fixup -C or --fixup=reword: commits" ;;
      *) die "plan: unsupported todo command '$verb' in: $line" ;;
    esac
    case $rest in -C\ *|-c\ *) rest=${rest#* };; esac
    sha=${rest%% *}
    if ! git merge-base --is-ancestor "$sha" "$OLD" 2>/dev/null || git merge-base --is-ancestor "$sha" "$BASE" 2>/dev/null; then
      die "plan: $sha is not a commit in $BASE_REF..HEAD"
    fi
    shas="$shas $(git rev-parse "$sha")"
    n=$((n + 1))
  done < "$plan"
  [ "$n" -gt 0 ] || die "plan: no todo lines found"
  # Every commit in range must be named. An omitted line leaves git parked on
  # --edit-todo, and a silent drop is exactly what this check exists to prevent.
  for full in $(git rev-list "$BASE..$OLD"); do
    found=0
    for sha in $shas; do [ "$sha" = "$full" ] && { found=1; break; }; done
    [ "$found" -eq 1 ] || die "plan omits $(git log -1 --format='%h %s' "$full"); add 'drop <sha>' to delete it deliberately"
  done
}

cmd_squash() {
  local base='' msgfile='' signoff=''
  while [ $# -gt 0 ]; do case $1 in --base) base=$2; shift 2;; --message-file) msgfile=$2; shift 2;; *) die "squash: unknown argument $1";; esac; done
  [ -n "$msgfile" ] || die "squash: --message-file <file> is required"
  check_message "$msgfile"
  preflight "$base"
  signoff_used "$BASE" "$OLD" && signoff=--signoff
  backup squash
  save_state tree "$BASE"
  note "squashing $COUNT commits from $BASE_REF into one"
  git reset --soft "$BASE"
  # shellcheck disable=SC2086  # $signoff is intentionally empty or one flag
  git commit --quiet $signoff -F "$msgfile"
  COUNT_HINT=1 verify tree "$OLD" "$BASE" "$BASE"
  report "$BASE"
}

cmd_fold() {
  local base='' plan='' mode=tree
  while [ $# -gt 0 ]; do case $1 in --base) base=$2; shift 2;; --plan) plan=$2; shift 2;; *) die "fold: unknown argument $1";; esac; done
  preflight "$base"
  if [ -n "$plan" ]; then
    [ -s "$plan" ] || die "fold: plan file '$plan' is missing or empty"
    validate_plan "$plan"
    grep -Eq '^(drop|d) ' "$plan" && mode=drop
    backup fold
    save_state "$mode" "$BASE"
    note "replaying $COUNT commits with plan $plan"
    # cp replaces the todo git generated with the reviewed plan; missingCommitsCheck
    # turns an accidentally omitted line into an error instead of a silent drop.
    GIT_SEQUENCE_EDITOR="cp '$plan'" git -c rebase.missingCommitsCheck=error rebase -i "$BASE" || conflict_exit
  else
    git log --format=%s "$BASE..HEAD" | grep -Eq '^(fixup|squash|amend)! ' \
      || die "fold: no fixup!/squash!/amend! commits in $BASE_REF..HEAD; create them with git commit --fixup=<sha> (or --fixup=amend:<sha> / --fixup=reword:<sha>) first"
    backup fold
    save_state tree "$BASE"
    note "autosquashing $COUNT commits from $BASE_REF"
    # -i with a no-op sequence editor works on every git version; bare --autosquash needs 2.44+.
    GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash "$BASE" || conflict_exit
  fi
  COUNT_HINT=$COUNT verify "$mode" "$OLD" "$BASE" "$BASE"
  report "$BASE"
}

cmd_rebase() {
  local onto='' fetch=1 onto_sha full remote
  while [ $# -gt 0 ]; do case $1 in --onto) onto=$2; shift 2;; --no-fetch) fetch=0; shift;; *) die "rebase: unknown argument $1";; esac; done
  [ -n "$onto" ] || die "rebase: --onto <ref> is required"
  need_repo
  full=$(git rev-parse --symbolic-full-name "$onto" 2>/dev/null || true)
  if [ "$fetch" -eq 1 ] && [ "${full#refs/remotes/}" != "$full" ]; then
    remote=${full#refs/remotes/}; remote=${remote%%/*}
    note "fetching $remote"; git fetch --quiet "$remote"
  fi
  preflight "$onto"
  onto_sha=$(git rev-parse "$onto^{commit}")
  [ "$onto_sha" != "$BASE" ] || die "already based on $onto (${BASE:0:12}); nothing to do"
  backup rebase
  save_state rebase "$onto_sha"
  note "rebasing $COUNT commits from ${BASE:0:12} onto $onto (${onto_sha:0:12})"
  git rebase "$onto_sha" || conflict_exit
  COUNT_HINT=$COUNT verify rebase "$OLD" "$BASE" "$onto_sha"
  report "$onto_sha"
}

cmd_verify() {
  local old='' base=''
  while [ $# -gt 0 ]; do case $1 in --old) old=$2; shift 2;; --base) base=$2; shift 2;; *) die "verify: unknown argument $1";; esac; done
  need_repo
  in_rebase && die "rebase still in progress; finish it first"
  if [ -z "$old" ]; then
    [ -f "$STATE" ] || die "verify: no previous run recorded; pass --old <sha> --base <sha>"
    # shellcheck disable=SC1090
    . "$STATE"
    old=$OLD; base=$BASE
    # shellcheck disable=SC2153  # MODE, NEWBASE come from the sourced state file
    COUNT_HINT=$(git rev-list --count "$base..$old") verify "$MODE" "$old" "$base" "$NEWBASE"
    report "$NEWBASE"
  else
    [ -n "$base" ] || die "verify: --base <sha> is required with --old"
    BACKUP="<see git for-each-ref refs/backup/$BRANCH/>"
    COUNT_HINT=$(git rev-list --count "$base..$old") verify tree "$old" "$base" "$base"
    report "$base"
  fi
}

cmd_restore() {
  local ref=${1:-} cur target
  [ -n "$ref" ] || die "usage: restore <backup-ref>   (list: git for-each-ref refs/backup/<branch>/)"
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git work tree"
  GIT_DIR_PATH=$(git rev-parse --git-dir)
  git rev-parse --verify --quiet "$ref^{commit}" >/dev/null || die "ref '$ref' does not resolve"
  # HEAD is detached while a rebase is stopped, so abort before asking for the branch.
  if in_rebase; then note "aborting the in-progress rebase"; git rebase --abort; fi
  need_repo
  dirty && die "work tree is dirty; commit first so nothing is lost"
  cur=$(git rev-parse HEAD); target=$(git rev-parse "$ref^{commit}")
  # Two-tree read updates index and work tree from HEAD to the target; it refuses
  # rather than clobbering, but the tree is clean so nothing can be clobbered.
  git read-tree -u -m HEAD "$target"
  git update-ref -m "clean-history: restore from $ref" "refs/heads/$BRANCH" "$target" "$cur"
  dirty && die "restore left the work tree inconsistent with HEAD; inspect git status"
  note "$BRANCH restored to ${target:0:12} (was ${cur:0:12})"
  git log --oneline -5
}

COUNT_HINT=${COUNT_HINT:-0}
sub=${1:-}; [ $# -gt 0 ] && shift
case $sub in
  status)  cmd_status "$@" ;;
  plan)    cmd_plan "$@" ;;
  squash)  cmd_squash "$@" ;;
  fold)    cmd_fold "$@" ;;
  rebase)  cmd_rebase "$@" ;;
  verify)  cmd_verify "$@" ;;
  restore) cmd_restore "$@" ;;
  ''|-h|--help) sed -n '2,20p' "$SELF" | sed 's/^# \{0,1\}//' ;;
  *) die "unknown subcommand '$sub' (status|plan|squash|fold|rebase|verify|restore)" ;;
esac
