#!/usr/bin/env bash
set -e

INTEGRATION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
TARGET_COMMANDS="$CLAUDE_DIR/commands"
TARGET_SKILLS="$CLAUDE_DIR/skills"

# Parse flags
PER_REPO=false
REPO_ROOT=""

for arg in "$@"; do
  case $arg in
    --per-repo)
      PER_REPO=true
      ;;
    --repo=*)
      REPO_ROOT="${arg#*=}"
      ;;
  esac
done

if [ "$PER_REPO" = true ]; then
  ROOT="${REPO_ROOT:-$(pwd)}"
  TARGET_COMMANDS="$ROOT/.claude/commands"
  TARGET_SKILLS="$ROOT/.claude/skills"
  echo "Installing Atlas (Claude Code) into $ROOT/.claude/ ..."
else
  echo "Installing Atlas (Claude Code) globally into $CLAUDE_DIR ..."
fi

mkdir -p "$TARGET_COMMANDS"
mkdir -p "$TARGET_SKILLS"

# Install commands
COMMANDS_INSTALLED=0
for f in "$INTEGRATION_DIR/commands/"*.md; do
  [ -f "$f" ] || continue
  cp "$f" "$TARGET_COMMANDS/"
  COMMANDS_INSTALLED=$((COMMANDS_INSTALLED + 1))
done

# Install skills (each skill is a directory with a SKILL.md)
SKILLS_INSTALLED=0
for skill_dir in "$INTEGRATION_DIR/skills/"/*/; do
  [ -d "$skill_dir" ] || continue
  skill_name="$(basename "$skill_dir")"
  mkdir -p "$TARGET_SKILLS/$skill_name"
  cp "$skill_dir/SKILL.md" "$TARGET_SKILLS/$skill_name/SKILL.md"
  SKILLS_INSTALLED=$((SKILLS_INSTALLED + 1))
done

echo ""
echo "Atlas installed successfully."
echo "  Commands : $COMMANDS_INSTALLED  →  $TARGET_COMMANDS"
echo "  Skills   : $SKILLS_INSTALLED  →  $TARGET_SKILLS"
echo ""
echo "Available commands:"
for f in "$TARGET_COMMANDS/"*.md; do
  [ -f "$f" ] || continue
  name="$(basename "$f" .md)"
  echo "  /$name"
done
echo ""

if [ "$PER_REPO" = true ]; then
  echo "Tip: commit .claude/ so the whole team gets Atlas automatically."
  echo "  git add .claude/ && git commit -m \"Add Atlas commands and skills\""
fi
