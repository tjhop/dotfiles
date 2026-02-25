#!/usr/bin/env bash
# ~/.claude/statusline-command.sh
# Status line for Claude Code.
# Reads JSON from stdin as documented in the statusLine command spec.

input=$(cat)

# --- Data extraction ---
dir=$(echo "$input" | jq -r '.workspace.current_dir')
model=$(echo "$input" | jq -r '.model.display_name')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
transcript=$(echo "$input" | jq -r '.transcript_path // empty')

# --- Git info ---
git_info=""
if git -C "$dir" --no-optional-locks rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$dir" --no-optional-locks branch --show-current 2>/dev/null)
  if [ -n "$branch" ]; then
    changes=""
    if ! git -C "$dir" --no-optional-locks diff --quiet 2>/dev/null \
    || ! git -C "$dir" --no-optional-locks diff --cached --quiet 2>/dev/null; then
      changes=" *"
    fi
    git_info=$(printf '\033[34m(%s%s)\033[0m ' "$branch" "$changes")
  fi
fi

# --- Context window ---
ctx_info=""
if [ -n "$used" ]; then
  ctx_info=$(printf '\033[33m[ctx: %s%%]\033[0m ' "$used")
fi

# --- 5-hour working block timer ---
# Derive session start from transcript file creation time (ctime).
# Falls back gracefully if the transcript path is absent or stat fails.
block_info=""
BLOCK_SECONDS=$((5 * 3600))
if [ -n "$transcript" ] && [ -e "$transcript" ]; then
  # stat -c %Y gives modification time; use %W (birth) when available,
  # falling back to %Y (mtime, which equals ctime on first write for new files).
  session_start=$(stat -c '%W' "$transcript" 2>/dev/null)
  # %W returns 0 if birth time is unsupported by the filesystem.
  if [ -z "$session_start" ] || [ "$session_start" -eq 0 ] 2>/dev/null; then
    session_start=$(stat -c '%Y' "$transcript" 2>/dev/null)
  fi
  if [ -n "$session_start" ] && [ "$session_start" -gt 0 ] 2>/dev/null; then
    now=$(date +%s)
    elapsed=$(( now - session_start ))
    remaining=$(( BLOCK_SECONDS - elapsed ))
    if [ "$remaining" -le 0 ]; then
      # Block has elapsed -- show overrun in bold red.
      overrun=$(( -remaining ))
      overrun_h=$(( overrun / 3600 ))
      overrun_m=$(( (overrun % 3600) / 60 ))
      block_info=$(printf '\033[1;31m[BLOCK +%dh%02dm]\033[0m ' "$overrun_h" "$overrun_m")
    else
      rem_h=$(( remaining / 3600 ))
      rem_m=$(( (remaining % 3600) / 60 ))
      # Color shifts from green -> yellow -> red as time runs out.
      if [ "$remaining" -gt 3600 ]; then
        color='\033[32m'   # green: more than 1h left
      elif [ "$remaining" -gt 1800 ]; then
        color='\033[33m'   # yellow: 30m-1h left
      else
        color='\033[31m'   # red: under 30m left
      fi
      block_info=$(printf "${color}[block: %dh%02dm]\033[0m " "$rem_h" "$rem_m")
    fi
  fi
fi

# --- Render ---
# printf '\033[36m%s\033[0m %s%s%s\033[35m%s\033[0m' \
  # "$dir" "$git_info" "$ctx_info" "$block_info" "$model"
# remove block info for now, not sure if I like the format/want to keep it
printf '\033[36m%s\033[0m %s%s\033[35m%s\033[0m' \
  "$dir" "$git_info" "$ctx_info" "$model"
