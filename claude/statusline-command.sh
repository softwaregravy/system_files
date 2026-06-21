#!/bin/sh
input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Build status parts
parts=""
[ -n "$model" ] && parts="$model"
[ -n "$cwd" ] && parts="$parts  $cwd"
[ -n "$used" ] && parts="$parts  ctx:$(printf '%.0f' "$used")%"

# Print in red
printf '\033[31m%s\033[0m' "$parts"
