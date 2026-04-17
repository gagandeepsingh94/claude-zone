#!/usr/bin/env bash
set -e

INTEGRATION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
TARGET_COMMANDS="$CLAUDE_DIR/commands"
TARGET_SKILLS="$CLAUDE_DIR/skills"

# Parse flags
PER_REPO=false
REPO_ROOT=""
MODE="skill"   # "skill" (default, single atlas skill) | "full" (5 commands + 5 skills)

for arg in "$@"; do
  case $arg in
    --per-repo)
      PER_REPO=true
      ;;
    --repo=*)
      REPO_ROOT="${arg#*=}"
      ;;
    --full)
      MODE="full"
      ;;
    --skill)
      MODE="skill"
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

mkdir -p "$TARGET_SKILLS"

if [ "$MODE" = "skill" ]; then
  # Install as a single self-contained atlas skill
  mkdir -p "$TARGET_SKILLS/atlas"
  cp "$INTEGRATION_DIR/skills/atlas/SKILL.md" "$TARGET_SKILLS/atlas/SKILL.md"

  echo ""
  echo "Atlas installed successfully (single-skill mode)."
  echo "  Skill: atlas  →  $TARGET_SKILLS/atlas/SKILL.md"
  echo ""
  echo "The atlas skill handles all operations:"
  echo "  - Codebase Overview   (generate .atlas/codebase-index.json + .atlas/codebase-overview.md)"
  echo "  - Ask Atlas           (Q&A from pre-built docs, no re-traversal)"
  echo "  - Architecture Diagram (draw.io, Excalidraw, Mermaid)"
  echo "  - ML Overview         (.atlas/ml-overview.md)"
  echo "  - Ecosystem Overview  (cross-repo dependency map)"
  echo ""
  echo "Usage examples:"
  echo "  \"Document this codebase\"           → runs Codebase Overview"
  echo "  \"How does the auth flow work?\"      → runs Ask Atlas"
  echo "  \"Generate an architecture diagram\" → runs Architecture Diagram"
  echo ""
  echo "To reinstall with separate commands + skills: ./install.sh --full"

else
  # Full mode: install 5 commands + 5 skills (classic layout)
  mkdir -p "$TARGET_COMMANDS"

  COMMANDS_INSTALLED=0
  for f in "$INTEGRATION_DIR/commands/"*.md; do
    [ -f "$f" ] || continue
    cp "$f" "$TARGET_COMMANDS/"
    COMMANDS_INSTALLED=$((COMMANDS_INSTALLED + 1))
  done

  SKILLS_INSTALLED=0
  for skill_dir in "$INTEGRATION_DIR/skills/"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "$skill_dir")"
    # skip the unified atlas skill in full mode — install individual skills only
    [ "$skill_name" = "atlas" ] && continue
    mkdir -p "$TARGET_SKILLS/$skill_name"
    cp "$skill_dir/SKILL.md" "$TARGET_SKILLS/$skill_name/SKILL.md"
    SKILLS_INSTALLED=$((SKILLS_INSTALLED + 1))
  done

  echo ""
  echo "Atlas installed successfully (full mode)."
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
  echo "To install as a single skill instead: ./install.sh --skill"
fi

if [ "$PER_REPO" = true ]; then
  echo "Tip: commit .claude/ so the whole team gets Atlas automatically."
  echo "  git add .claude/ && git commit -m \"Add Atlas\""
fi
