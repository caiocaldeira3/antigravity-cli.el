#!/usr/bin/env sh
# This script was used to migrate from claude-code to antigravity-cli.
# It is kept for historical reference.

sed -i -e 's/claude-code/antigravity-cli/g' \
    -e 's/Claude Code/Antigravity CLI/g' \
    -e 's/Claude/Antigravity/g' \
    -e 's/claude/antigravity/g' \
    -e 's/compact/compress/g' \
    -e 's/Compact/Compress/g' \
    -e 's/Exit/Quit/g' \
    -e 's/exit/quit/g' \
    "$1"
