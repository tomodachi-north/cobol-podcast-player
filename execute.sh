#!/usr/bin/env bash
#==============================================================================
# execute.sh — standard way to build & run podcast-player.cob
#
# Compiles the FREE-format COBOL source and launches the TUI inside a tmux
# session sized to 120x40 (the player draws an ~88-column box and relies on
# ANSI positioning, so a fixed, large-enough pane is required).
#
# Usage:
#   ./execute.sh                  # build, then run interactively (attached)
#   ./execute.sh -c               # build, then capture the now-playing screen
#   ./execute.sh -c -e 3          # capture after selecting episode 3
#   ./execute.sh -c --raw         # capture WITH ANSI colour escape codes
#   ./execute.sh -b               # build only, do not run
#
# Needs: cobc (GnuCOBOL 3.x), tmux, and runtime deps curl/ffplay/ffprobe.
#==============================================================================
set -euo pipefail

SRC="podcast-player.cob"
BINARY="./podcast-player"
SESSION="cobplay_$$"
COLS=120
ROWS=40

MODE="run"        # run | capture | build
EPISODE="1"       # episode to select in capture mode
RAW=0             # 1 = keep ANSI escape codes in capture output

#──────────────────────────────────────────────────────────────────────────────
# Parse arguments
#──────────────────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--capture) MODE="capture" ;;
        -b|--build)   MODE="build" ;;
        -e|--episode) EPISODE="$2"; shift ;;
        --raw)        RAW=1 ;;
        -h|--help)    grep '^#' "$0" | sed 's/^#//'; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

#──────────────────────────────────────────────────────────────────────────────
# Build
#──────────────────────────────────────────────────────────────────────────────
echo "Compiling $SRC ..."
cobc -free -x "$SRC" -o "$BINARY"
echo "Build OK -> $BINARY"
[[ "$MODE" == "build" ]] && exit 0

#──────────────────────────────────────────────────────────────────────────────
# Run interactively (attached)
#──────────────────────────────────────────────────────────────────────────────
if [[ "$MODE" == "run" ]]; then
    tmux kill-session -t "$SESSION" 2>/dev/null || true
    tmux new-session -s "$SESSION" -x "$COLS" -y "$ROWS" \
         "TERM=xterm-256color $BINARY"
    exit 0
fi

#──────────────────────────────────────────────────────────────────────────────
# Capture mode — drive the TUI headless and dump the rendered screen
#──────────────────────────────────────────────────────────────────────────────
tmux kill-session -t "$SESSION" 2>/dev/null || true
tmux new-session -d -s "$SESSION" -x "$COLS" -y "$ROWS" \
     "TERM=xterm-256color $BINARY"
sleep 4                                    # RSS fetch + first render
tmux send-keys -t "$SESSION" "$EPISODE" Enter
sleep 5                                    # now-playing render

if [[ "$RAW" -eq 1 ]]; then
    tmux capture-pane -t "$SESSION" -p -e   # keep colour escape codes
else
    tmux capture-pane -t "$SESSION" -p \
        | sed 's/\x1b\[[0-9;]*[mKHJABCDGsu]//g'   # strip escape sequences
fi

tmux kill-session -t "$SESSION" 2>/dev/null || true
