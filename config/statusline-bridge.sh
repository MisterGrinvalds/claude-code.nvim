#!/bin/bash
# Claude Code Status Bridge
# Receives status JSON from Claude CLI, writes to temp file for Neovim integration
#
# Install: Copy to ~/.claude/statusline-bridge.sh and chmod +x

# Use project-specific status file (supports multiple instances)
STATE_DIR="${CLAUDE_PROJECT_DIR:-/tmp}"
STATUS_FILE="${STATE_DIR}/.claude-status.json"

# Read JSON from stdin
input=$(cat)

# Write to temp file for Neovim to read
echo "$input" > "$STATUS_FILE"

# Output status line for Claude's display
MODEL=$(echo "$input" | jq -r '.model.display_name // "Claude"')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
TOKENS=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
LINES_ADD=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
LINES_DEL=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

# Format tokens (k/M suffix)
if [ "$TOKENS" -ge 1000000 ]; then
  TOKENS_FMT=$(printf "%.1fM" $(echo "scale=1; $TOKENS/1000000" | bc))
elif [ "$TOKENS" -ge 1000 ]; then
  TOKENS_FMT=$(printf "%.1fk" $(echo "scale=1; $TOKENS/1000" | bc))
else
  TOKENS_FMT="$TOKENS"
fi

# Output: [Model] tokens | +add/-del | $cost
printf "[%s] %s tokens | +%s/-%s | \$%.4f" "$MODEL" "$TOKENS_FMT" "$LINES_ADD" "$LINES_DEL" "$COST"
