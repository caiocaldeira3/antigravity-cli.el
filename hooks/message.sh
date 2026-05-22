#!/bin/bash

input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // ""')

transcript=$(find "$HOME/.antigravity/projects" -name "${session_id}.jsonl" 2>/dev/null | head -1)
[ -z "$transcript" ] && exit 0

last_assistant=$(grep '"role":"assistant"' "$transcript" 2>/dev/null | tail -1)

# Check for AskUserQuestion tool use
ask_user_options=$(echo "$last_assistant" | jq -r '
  .message.content |
  if type == "array" then
    map(select(.type == "tool_use" and .name == "AskUserQuestion")) |
    first |
    if . then
      .input.questions[0].options | map(.label) | .[]
    else empty end
  else empty end' 2>/dev/null)

if [ -n "$ask_user_options" ]; then
  options=()
  while IFS= read -r line; do
    options+=("$line")
  done <<< "$ask_user_options"

  elisp_list=$(printf '%s\n' "${options[@]}" | jq -Rs 'split("\n") | map(select(length > 0)) | map("\"" + gsub("\""; "\\\"") + "\"") | "(" + join(" ") + ")"' -r)
  result=$(emacsclient --eval "(completing-read \"Select: \" '${elisp_list} nil t)" 2>/dev/null | tr -d '"')
  [ -n "$result" ] && echo "{\"hookSpecificOutput\": {\"hookEventName\": \"Stop\", \"additionalContext\": \"User selected: $result\"}}"
  exit 0
fi

# Fall back to plain text numbered options
last_text=$(echo "$last_assistant" | jq -r '
  .message.content |
  if type == "array" then map(select(.type == "text") | .text) | join("")
  elif type == "string" then .
  else "" end' 2>/dev/null)

[ -z "$last_text" ] && exit 0

echo "$last_text" | grep -qE '^\s*[1-4][.)]\s' || exit 0

options=()
while IFS= read -r line; do
  options+=("$line")
done < <(echo "$last_text" | grep -E '^\s*[1-4][.)]\s' | sed 's/^\s*//')

[ ${#options[@]} -eq 0 ] && exit 0

elisp_list=$(printf '%s\n' "${options[@]}" | jq -Rs 'split("\n") | map(select(length > 0)) | map("\"" + gsub("\""; "\\\"") + "\"") | "(" + join(" ") + ")"' -r)
result=$(emacsclient --eval "(completing-read \"Select: \" '${elisp_list} nil t)" 2>/dev/null | tr -d '"')
[ -n "$result" ] && echo "{\"hookSpecificOutput\": {\"hookEventName\": \"Stop\", \"additionalContext\": \"User selected: $result\"}}"
