#!/usr/bin/env bash
# Run independent environment checks without blocking session startup.
# Requires jq only for hook-mode JSON; without it the lines print plain, which
# SessionStart also accepts as context. Exit 0 for help, check failures, and
# runner errors.
case "${1:-}" in
  --help|-h)
    printf '%s\n' 'Usage: preflight.sh [--plain]' \
      'SessionStart JSON on stdin produces additionalContext; compact is skipped.' \
      'Otherwise prints check lines and totals. Each check has a two-second limit.' \
      'CLAUDE_PREFLIGHT_DIR overrides ~/.claude/hooks/preflight.d.'
    exit 0 ;;
  --plain|'') ;;
  *) printf '%s\n' 'preflight: runner error -- unknown argument (use --help)'; exit 0 ;;
esac

hook_mode=false
if [ "${1:-}" != --plain ] && [ ! -t 0 ] && command -v jq >/dev/null 2>&1; then
  input=$(cat)
  event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)
  src=$(printf '%s' "$input" | jq -r '.source // empty' 2>/dev/null)
  if [ "$event" = SessionStart ]; then
    hook_mode=true
    [ "$src" = compact ] && exit 0
  fi
fi

dir=${CLAUDE_PREFLIGHT_DIR:-$HOME/.claude/hooks/preflight.d}
limit=2
work=$(mktemp -d "${TMPDIR:-/tmp}/preflight.XXXXXX") || { printf '%s\n' 'preflight: runner error -- mktemp failed'; exit 0; }
trap 'rm -rf "$work"' EXIT
out=$work/out timed=$work/timed

# Run one check with stdin closed and stderr dropped, killed at the limit.
# Leaves its stdout in $out; returns 124 on timeout, otherwise the check's
# status. The watchdog gets no shared descriptors, so a leftover sleep cannot
# hold the hook's stdout open.
run_check() {
  local script=$1 pid watchdog status
  rm -f "$out" "$timed"
  bash "$script" </dev/null >"$out" 2>/dev/null &
  pid=$!
  { sleep "$limit"; kill -KILL "$pid" 2>/dev/null && : >"$timed"; } </dev/null >/dev/null 2>&1 &
  watchdog=$!
  wait "$pid" 2>/dev/null; status=$?
  # 137 means SIGKILL: let the watchdog finish so its marker is reliable.
  if [ "$status" -ne 137 ]; then
    pkill -KILL -P "$watchdog" 2>/dev/null; kill -KILL "$watchdog" 2>/dev/null
  fi
  wait "$watchdog" 2>/dev/null
  [ -e "$timed" ] && return 124
  return "$status"
}

shape='^[^:]+: (ok|warn|fail|skip) -- .+$'
lines=() ok=0 warn=0 fail=0 skip=0
for script in "$dir"/*.sh; do
  [ -f "$script" ] || continue
  name=${script##*/}; name=${name%.sh}; name=${name//[^A-Za-z0-9_.-]/_}
  if [ ! -r "$script" ]; then
    line="$name: fail -- could not start check"
  else
    run_check "$script"; status=$?
    output=$(<"$out")
    if [ "$status" -eq 124 ]; then
      line="$name: fail -- check timed out"
    elif [ "$status" -ne 0 ]; then
      line="$name: fail -- check exited with status $status"
    elif [[ $output == *$'\n'* ]] || ! [[ $output =~ $shape ]]; then
      line="$name: fail -- invalid check output"
    else
      line=$output
    fi
  fi
  lines+=("$line")
  case "${line#*: }" in
    ok*)   ok=$((ok + 1)) ;;
    warn*) warn=$((warn + 1)) ;;
    fail*) fail=$((fail + 1)) ;;
    skip*) skip=$((skip + 1)) ;;
  esac
done

if [ "$hook_mode" = true ]; then
  [ ${#lines[@]} -eq 0 ] && exit 0
  joined=
  for line in "${lines[@]}"; do joined="${joined:+$joined; }$line"; done
  jq -cn --arg ctx "preflight: $joined" \
    '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
else
  printf '%s\n' "${lines[@]}" "preflight: $ok ok, $warn warn, $fail fail, $skip skip"
fi
exit 0
