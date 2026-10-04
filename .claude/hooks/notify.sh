#!/usr/bin/env bash
# Desktop notification for Claude Code Notification hook events, titled with the
# session name the agents view shows so parallel agents stay attributable.
#
#   Title     the session or job name (session registry > job state > directory)
#   Subtitle  what it needs · where it runs · job id
#   Body      the question, the tool awaiting permission, or the outcome
#
# A block is reported twice: by the agent itself (permission_prompt) and by the
# agents view (agent_needs_input). Repeats for the same session and class within
# NOTIFY_DEDUP_SECONDS are dropped. Every decision is appended to the log so a
# notification can be traced back to its session afterwards.
#
# Requires jq; desktop tools and tmux are optional. Exit 0 in all cases.
dry_run=
case "${1:-}" in
  --help|-h)
    printf '%s\n' 'Usage: notify.sh [--dry-run] < notification.json' \
      'Resolve the session name from the hook payload, then notify via' \
      'terminal-notifier or osascript on macOS, notify-send on Linux, and ring' \
      'the tmux pane bell. --dry-run prints the resolved fields instead.' \
      'Env: NOTIFY_DEDUP_SECONDS (default 60), NOTIFY_ACTIVATE_BUNDLE (app to' \
      'focus on click with terminal-notifier), CLAUDE_CONFIG_DIR, XDG_STATE_HOME.' \
      "Log: ${XDG_STATE_HOME:-$HOME/.local/state}/claude-code/notify/notify.log"
    exit 0 ;;
  --dry-run) dry_run=1 ;;
esac

input=$(cat)
field() { printf '%s' "$input" | jq -r --arg k "$1" '.[$k] // empty | select(type == "string")' 2>/dev/null; }
message=$(field message)
kind=$(field notification_type)
payload_title=$(field title)
sid=$(field session_id)
hook_cwd=$(field cwd)
[ -n "$message" ] || message='Claude Code needs your attention'

claude_dir=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/claude-code/notify
window=${NOTIFY_DEDUP_SECONDS:-60}

# Session registry: the records the agents view itself reads. Newest wins.
# Prints name, nameSource, kind, jobId, cwd, spare on one line, unit-separated.
registry_lookup() {
  jq -rs --arg sid "$sid" --arg label "$1" '
    [ .[] | select(type == "object") | select(if $label == "" then .sessionId == $sid else .name == $label end) ]
    | sort_by(.updatedAt // 0) | last // empty
    | [ (.name // ""), (.nameSource // ""), (.kind // ""), (.jobId // ""), (.cwd // ""), ((.spare // false) | tostring) ] | join("\u001f")
  ' "$claude_dir"/sessions/*.json 2>/dev/null
}

# Background job state: adds the short id and the tool description in flight.
# Prints name, daemonShort, cwd, state, detail on one line, unit-separated.
job_lookup() {
  jq -rs --arg sid "$sid" --arg label "$1" '
    [ .[] | select(type == "object")
      | select(if $label == "" then (.sessionId == $sid or .resumeSessionId == $sid) else .name == $label end) ]
    | sort_by(.updatedAt // 0) | last // empty
    | [ (.name // ""), (.daemonShort // ""), (.cwd // ""), (.state // ""), (.detail // "") ] | join("\u001f")
  ' "$claude_dir"/jobs/*/state.json 2>/dev/null
}

# Mirror the agents view fallback label: first three words, at most 25 chars.
# A registry record without a nameSource still carries the raw prompt as its name.
shorten() {
  jq -rn --arg s "$1" '
    if ($s | length) <= 40 then $s else
      ($s | split(" ") | map(select(length > 0))) as $w
      | ($w[:3] | join(" ")) + (if ($w | length) > 3 then "\u2026" else "" end)
      | if length > 25 then .[:24] + "\u2026" else . end
    end'
}

# repo:worktree for a Claude worktree checkout, otherwise the directory name.
where_of() {
  local p=${1%/} repo wt
  case "$p" in
    "") ;;
    */.claude/worktrees/*)
      wt=${p##*/.claude/worktrees/}; wt=${wt%%/*}
      repo=${p%%/.claude/worktrees/*}
      printf '%s:%s' "${repo##*/}" "$wt" ;;
    *) printf '%s' "${p##*/}" ;;
  esac
}

label= needs= outcome=
case "$kind" in
  agent_needs_input)
    # Message shape: "<label> needs your input: <needs>" or "<label> needs your input".
    label=${message%% needs your input*}
    needs=${message#* needs your input}; needs=${needs#: } ;;
  agent_completed)
    # Message shape: "<label> finished" or "<label> failed".
    outcome=${message##* }
    label=${message% *} ;;
esac

name= name_source= reg_kind= job_id= cwd= spare= job_state= job_detail=
# Unit separator rather than tab: bash folds runs of tabs, which would shift empty fields.
us=$(printf '\x1f')
IFS=$us read -r name name_source reg_kind job_id cwd spare <<<"$(registry_lookup "$label")"
IFS=$us read -r j_name j_short j_cwd job_state job_detail <<<"$(job_lookup "$label")"
[ -n "$name" ] || name=$j_name
[ -n "$job_id" ] || job_id=$j_short
[ -n "$cwd" ] || cwd=$j_cwd
[ -n "$cwd" ] || cwd=$hook_cwd
# Spare pool sessions are named after their job id, which tells the reader nothing.
[ "$spare" = true ] && name=
[ -n "$name" ] && [ -z "$name_source" ] && name=$(shorten "$name")
[ -n "$name" ] || name=$label
where=$(where_of "$cwd")
title=${name:-${where:-Claude Code}}

case "$kind" in
  permission_prompt)   verb='needs permission'; class=attention ;;
  agent_needs_input)   verb='needs input';      class=attention ;;
  idle_prompt)         verb='waiting on you';   class=done ;;
  agent_completed)     verb=${outcome:-finished}; class=done ;;
  *)                   verb=${kind:-notice};    class=${kind:-other} ;;
esac
subtitle=$verb
[ -n "$where" ] && [ "$where" != "$title" ] && subtitle="$subtitle · $where"
[ -n "$job_id" ] && subtitle="$subtitle · $job_id"

case "$kind" in
  permission_prompt)
    body=${message#Claude needs your permission to use }
    [ "$body" = "$message" ] || body="Permission: $body"
    # While a job is mid-turn its detail is the description of the tool call waiting.
    [ "$job_state" = working ] && [ -n "$job_detail" ] && body="$body · $job_detail" ;;
  agent_needs_input)
    body=${needs:-needs your input} ;;
  agent_completed)
    body="$title ${outcome:-finished}" ;;
  *)
    body=$message ;;
esac
[ -n "$payload_title" ] && body="$payload_title: $body"

# Drop a repeat of the same session and class inside the window. The name joins
# the agent's own report with the agents view's; an unnamed session keys on its id.
suppressed=false
if [ -n "$sid$label" ]; then
  mkdir -p "$state_dir" 2>/dev/null
  key=${name:+$title}; key=${key:-$sid}
  digest=$(printf '%s|%s' "$key" "$class" | { shasum -a 256 2>/dev/null || sha256sum; } | cut -c1-16)
  key_file="$state_dir/k-$digest"
  now=$(date +%s)
  if [ -f "$key_file" ]; then
    mtime=$(stat -f %m "$key_file" 2>/dev/null || stat -c %Y "$key_file" 2>/dev/null || echo 0)
    [ $((now - mtime)) -lt "$window" ] && suppressed=true
  fi
  [ "$suppressed" = true ] || : > "$key_file" 2>/dev/null
  find "$state_dir" -name 'k-*' -mmin +60 -delete 2>/dev/null
fi

log() {
  [ -d "$state_dir" ] || return 0
  jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg kind "$kind" --arg title "$title" \
    --arg subtitle "$subtitle" --arg body "$body" --arg sid "$sid" --arg job "$job_id" \
    --arg cwd "$cwd" --argjson suppressed "$suppressed" \
    '{ts:$ts,kind:$kind,title:$title,subtitle:$subtitle,body:$body,session_id:$sid,job:$job,cwd:$cwd,suppressed:$suppressed}' \
    >> "$state_dir/notify.log" 2>/dev/null
  if [ "$(wc -l < "$state_dir/notify.log" 2>/dev/null || echo 0)" -gt 500 ]; then
    tail -n 300 "$state_dir/notify.log" > "$state_dir/notify.log.tmp" 2>/dev/null \
      && mv "$state_dir/notify.log.tmp" "$state_dir/notify.log"
  fi
}

activate_bundle() {
  [ -n "${NOTIFY_ACTIVATE_BUNDLE:-}" ] && { printf '%s' "$NOTIFY_ACTIVATE_BUNDLE"; return; }
  case "${TERM_PROGRAM:-}" in
    iTerm.app) printf 'com.googlecode.iterm2' ;;
    Apple_Terminal) printf 'com.apple.Terminal' ;;
    ghostty) printf 'com.mitchellh.ghostty' ;;
    WezTerm) printf 'com.github.wez.wezterm' ;;
    kitty) printf 'net.kovidgoyal.kitty' ;;
  esac
}

desktop_notification() {
  case "$(uname -s)" in
    Darwin)
      if command -v terminal-notifier >/dev/null 2>&1; then
        # One card per session: a newer event for the same title replaces the old one.
        args=(-title "$title" -subtitle "$subtitle" -message "$body" -group "claude-code:$title")
        bundle=$(activate_bundle)
        [ -n "$bundle" ] && args+=(-activate "$bundle")
        terminal-notifier "${args[@]}" >/dev/null 2>&1
      elif command -v osascript >/dev/null 2>&1; then
        osascript -e 'on run argv
          display notification (item 3 of argv) with title (item 1 of argv) subtitle (item 2 of argv)
        end run' "$title" "$subtitle" "$body" >/dev/null 2>&1
      fi ;;
    Linux)
      if command -v notify-send >/dev/null 2>&1; then
        notify-send -u normal -a 'Claude Code' -- "$title" "$subtitle: $body" >/dev/null 2>&1
      fi ;;
  esac
}

pane_bell() {
  if [ -n "${TMUX_PANE:-}" ] && command -v tmux >/dev/null 2>&1; then
    tty=$(tmux display-message -p -t "$TMUX_PANE" '#{pane_tty}' 2>/dev/null)
    if [ -n "$tty" ] && [ -w "$tty" ]; then
      printf '\a' > "$tty" 2>/dev/null
    fi
  fi
}

log
if [ -n "$dry_run" ]; then
  printf 'title=%s\nsubtitle=%s\nbody=%s\nsuppressed=%s\n' "$title" "$subtitle" "$body" "$suppressed"
  exit 0
fi
[ "$suppressed" = true ] && exit 0
desktop_notification; pane_bell
exit 0
