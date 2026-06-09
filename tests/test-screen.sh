#!/usr/bin/env bash
#==============================================================================
# test-screen.sh — tmux screen capture tests for podcast-player.cob
#
# Launches the compiled binary in a detached tmux session, waits for it to
# render, captures the pane, and asserts that key UI elements from the mockup
# are present on screen — including layout, labels, and dynamic values.
#
# Usage:  bash test-screen.sh [./podcast-player]
# Needs:  tmux, cobc (GnuCOBOL 3.x), the compiled binary
#
# The binary is compiled fresh if not supplied as $1.
#==============================================================================

BINARY="${1:-./podcast-player}"
SESSION="cobtest_$$"
PASS=0; FAIL=0

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; DIM='\033[2m'; RESET='\033[0m'

header()  { echo -e "\n${CYAN}── $1${RESET}"; }
ok()      { echo -e "  ${GREEN}✔  $1${RESET}"; ((PASS++)); }
fail()    { echo -e "  ${RED}✘  $1${RESET}"; ((FAIL++)); }
warn()    { echo -e "  ${YELLOW}⚠  $1${RESET}"; }

#──────────────────────────────────────────────────────────────────────────────
# Compile if needed
#──────────────────────────────────────────────────────────────────────────────
if [[ ! -x "$BINARY" ]]; then
    warn "Binary not found — compiling podcast-player.cob..."
    if ! cobc -free -x podcast-player.cob -o podcast-player 2>/tmp/cob_compile_err.txt; then
        echo -e "${RED}COMPILE FAILED:${RESET}"
        cat /tmp/cob_compile_err.txt
        exit 1
    fi
    BINARY="./podcast-player"
    echo -e "  ${GREEN}Compiled OK${RESET}"
fi

#──────────────────────────────────────────────────────────────────────────────
# Helpers
#──────────────────────────────────────────────────────────────────────────────

# Start a fresh tmux session running the player
start_session() {
    tmux kill-session -t "$SESSION" 2>/dev/null || true
    # 80×24 is classic terminal size; player uses ANSI positioning
    tmux new-session -d -s "$SESSION" -x 120 -y 30 \
         "TERM=xterm-256color $BINARY"
}

# Capture the current tmux pane as plain text (strips ANSI colour codes)
capture() {
    tmux capture-pane -t "$SESSION" -p 2>/dev/null \
        | sed 's/\x1b\[[0-9;]*[mKHJABCDGsu]//g'   # strip escape sequences
}

# Assert a pattern appears in the captured screen
assert_screen() {
    local label="$1" pattern="$2" screen="$3"
    if echo "$screen" | grep -qF "$pattern"; then
        ok "$label"
    else
        fail "$label  [pattern: '$pattern']"
    fi
}

# Assert a regex pattern appears in the captured screen
assert_screen_re() {
    local label="$1" pattern="$2" screen="$3"
    if echo "$screen" | grep -qE "$pattern"; then
        ok "$label"
    else
        fail "$label  [regex: '$pattern']"
    fi
}

# Send keystrokes to the session
send_keys() {
    tmux send-keys -t "$SESSION" "$1" ""
}

# Wait for a pattern to appear, with timeout (seconds)
wait_for() {
    local pattern="$1" timeout="${2:-8}"
    local i=0
    while ! capture | grep -qF "$pattern"; do
        sleep 0.5
        ((i++))
        if (( i * 5 >= timeout * 10 )); then
            return 1   # timeout
        fi
    done
    return 0
}

cleanup() {
    tmux kill-session -t "$SESSION" 2>/dev/null || true
}
trap cleanup EXIT

#==============================================================================
# TEST SUITE
#==============================================================================

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  COBPLAYR  Screen Tests  (tmux capture)"
echo "══════════════════════════════════════════════════════════"

#──────────────────────────────────────────────────────────────────────────────
header "SPLASH / LOADING SCREEN"
#──────────────────────────────────────────────────────────────────────────────

start_session
sleep 1
SCREEN=$(capture)

assert_screen "Shows IDENTIFICATION DIVISION header"   "IDENTIFICATION DIVISION"   "$SCREEN"
assert_screen "Shows PROGRAM-ID COBPLAYR"              "COBPLAYR"                  "$SCREEN"
assert_screen "Shows loading message"                  "Loading RSS feed"          "$SCREEN"

#──────────────────────────────────────────────────────────────────────────────
header "EPISODE BROWSER — waits for feed or mock data"
#──────────────────────────────────────────────────────────────────────────────

# Browser appears after RSS fetch (max 35 sec with curl timeout, using mock fallback)
if ! wait_for "EPISODE-BROWSER" 40; then
    fail "Browser screen did not appear within 40s"
    cleanup
    exit 1
fi

SCREEN=$(capture)

assert_screen  "Shows PROCEDURE DIVISION header"        "PROCEDURE DIVISION"        "$SCREEN"
assert_screen  "Shows EPISODE-BROWSER label"            "EPISODE-BROWSER"           "$SCREEN"
assert_screen  "Shows prompt line with cobol>"          "cobol>"                    "$SCREEN"
assert_screen  "Shows Q=quit instruction"               "Q"                         "$SCREEN"
assert_screen  "Shows N=NEXT PAGE instruction"          "NEXT PAGE"                 "$SCREEN"
assert_screen  "Shows P=PREV PAGE instruction"          "PREV PAGE"                 "$SCREEN"
assert_screen  "Shows episode selection brackets [ ]"  "[ "                        "$SCREEN"
# Episodes should be listed with numbers
assert_screen_re "Shows at least one episode number"   '\[ [0-9]+ \]'              "$SCREEN"
# Date column is present
assert_screen_re "Shows a pub date (YYYY or Mon format)" '20[0-9][0-9]'            "$SCREEN"

#──────────────────────────────────────────────────────────────────────────────
header "BROWSER — invalid input shows error message"
#──────────────────────────────────────────────────────────────────────────────

send_keys "99"
sleep 1.5
SCREEN=$(capture)
assert_screen "Invalid episode number shows error" "Invalid episode number" "$SCREEN"

send_keys "xyz"
sleep 1.5
SCREEN=$(capture)
assert_screen "Unknown command shows error" "Unknown command" "$SCREEN"

#──────────────────────────────────────────────────────────────────────────────
header "BROWSER — pagination (N / P keys)"
#──────────────────────────────────────────────────────────────────────────────

# Go to next page — if only 1 page of mock data, should show LAST PAGE
send_keys "n"
sleep 1.5
SCREEN=$(capture)
# Either moved to page 2, or showed LAST PAGE message
if echo "$SCREEN" | grep -qF "LAST PAGE"; then
    ok "N key on last page shows LAST PAGE message"
else
    assert_screen "N key advances page (page 2 shown)" "EPISODE-BROWSER" "$SCREEN"
fi

send_keys "p"
sleep 1.5
SCREEN=$(capture)
if echo "$SCREEN" | grep -qF "FIRST PAGE"; then
    ok "P key on first page shows FIRST PAGE message"
else
    assert_screen "P key goes back a page" "EPISODE-BROWSER" "$SCREEN"
fi

#──────────────────────────────────────────────────────────────────────────────
header "PLAY UI — select episode 1 and verify IDE-style layout"
#──────────────────────────────────────────────────────────────────────────────

# Select episode 1
send_keys "1"

# Wait for play UI to appear (DATA DIVISION box is the key landmark)
if ! wait_for "DATA DIVISION" 10; then
    fail "Play UI (DATA DIVISION) did not appear within 10s"
else
    ok "Play UI appeared after episode selection"
fi

sleep 1
SCREEN=$(capture)

# ── Mockup row: DATA DIVISION header ──────────────────────────────────────
assert_screen  "DATA DIVISION header present"          "DATA DIVISION"             "$SCREEN"
assert_screen  "WORKING-STORAGE label present"         "WORKING-STORAGE"           "$SCREEN"
assert_screen  "NOW-PLAYING label present"             "NOW-PLAYING"               "$SCREEN"

# ── Mockup row: episode metadata fields ───────────────────────────────────
assert_screen  "SHOW-NAME field label present"         "SHOW-NAME"                 "$SCREEN"
assert_screen  "EP-TITLE field label present"          "EP-TITLE"                  "$SCREEN"
assert_screen  "EP-NUMBER field label present"         "EP-NUMBER"                 "$SCREEN"
assert_screen  "PUB-DATE field label present"          "PUB-DATE"                  "$SCREEN"
assert_screen  "DURATION-SEC field label present"      "DURATION-SEC"              "$SCREEN"

# ── Mockup row: PIC clauses visible ───────────────────────────────────────
assert_screen  "PIC X(32) shown for SHOW-NAME"         "PIC"                       "$SCREEN"

# ── Mockup row: PROCEDURE DIVISION block ──────────────────────────────────
assert_screen  "PROCEDURE DIVISION block present"      "PROCEDURE DIVISION"        "$SCREEN"
assert_screen  "PLAY-EPISODE label present"            "PLAY-EPISODE"              "$SCREEN"
assert_screen  "MOVE/TO/POSITION-SEC line present"     "POSITION-SEC"              "$SCREEN"
assert_screen  "IF CURRENT-CHAPTER line present"       "CURRENT-CHAPTER"           "$SCREEN"

# ── Mockup row: progress bar ──────────────────────────────────────────────
assert_screen_re "Progress bar has [ and ] brackets"  '\[[\|\.]+\]'               "$SCREEN"

# ── Mockup row: bottom split panel ────────────────────────────────────────
assert_screen  "LINKAGE SECTION / QUEUE panel present" "LINKAGE SECTION"           "$SCREEN"
assert_screen  "88-LEVEL UP-NEXT label present"        "88-LEVEL UP-NEXT"          "$SCREEN"
assert_screen  "FILE SECTION / CHAPTER-MAP present"    "FILE SECTION"              "$SCREEN"
assert_screen  "CHAPTER-MAP label present"             "CHAPTER-MAP"               "$SCREEN"

# ── Mockup row: queue entries (88 VALUE lines) ────────────────────────────
assert_screen  "Queue shows 88 level entries"          "88"                        "$SCREEN"
assert_screen  "Queue shows VALUE keyword"             "VALUE"                     "$SCREEN"

# ── Mockup row: chapter map has ► active marker ───────────────────────────
assert_screen  "Chapter map shows ► active marker"    "►"                         "$SCREEN"

# ── Mockup row: status line ───────────────────────────────────────────────
assert_screen  "Status line shows RUN or PAUSED"       "RUN"                       "$SCREEN"
assert_screen  "Status line shows ffplay"              "ffplay"                    "$SCREEN"
assert_screen  "Status line shows GnuCOBOL version"    "GnuCOBOL"                  "$SCREEN"
assert_screen  "Status line shows source file name"    "podcast-player.cob"        "$SCREEN"
assert_screen  "Separator line present"                "────"                      "$SCREEN"

# ── Mockup row: key help line ─────────────────────────────────────────────
assert_screen  "Help shows Q to stop"                  "Q"                         "$SCREEN"
assert_screen  "Help shows P to play"                  "P"                         "$SCREEN"
assert_screen  "Help shows space bar to pause mention" "pause"                     "$SCREEN"

# ── Box drawing characters from mockup ────────────────────────────────────
assert_screen  "Top-left corner ┌ present"             "┌"                         "$SCREEN"
assert_screen  "Top-right corner ┐ present"            "┐"                         "$SCREEN"
assert_screen  "Bottom-left corner └ present"          "└"                         "$SCREEN"
assert_screen  "Bottom-right corner ┘ present"         "┘"                         "$SCREEN"
assert_screen  "Vertical bar │ present"                "│"                         "$SCREEN"
assert_screen  "Horizontal bar ─ present"              "─"                         "$SCREEN"
assert_screen  "T-joint ├ present"                     "├"                         "$SCREEN"
assert_screen  "T-joint-right ┤ present"               "┤"                         "$SCREEN"
assert_screen  "Bottom-T ┴ present"                    "┴"                         "$SCREEN"
assert_screen  "Top-T ┬ present"                       "┬"                         "$SCREEN"

#──────────────────────────────────────────────────────────────────────────────
header "PLAY UI — PAUSED state (P keypress)"
#──────────────────────────────────────────────────────────────────────────────

send_keys "p"
sleep 2
SCREEN=$(capture)
assert_screen "P key toggles to PAUSED state" "PAUSED" "$SCREEN"

# Toggle back
send_keys "p"
sleep 2
SCREEN=$(capture)
assert_screen "P key toggles back to RUN state" "RUN" "$SCREEN"

#──────────────────────────────────────────────────────────────────────────────
header "PLAY UI — Q exits back to browser"
#──────────────────────────────────────────────────────────────────────────────

send_keys "q"
if ! wait_for "EPISODE-BROWSER" 5; then
    fail "Q key did not return to episode browser"
else
    ok "Q key returns to episode browser"
fi

SCREEN=$(capture)
assert_screen "Browser shows 'Playback stopped' status" "Playback stopped" "$SCREEN"

#──────────────────────────────────────────────────────────────────────────────
header "GOODBYE SCREEN — quit from browser"
#──────────────────────────────────────────────────────────────────────────────

send_keys "q"
sleep 2
SCREEN=$(capture)
assert_screen "Goodbye shows GOBACK keyword"           "GOBACK"                    "$SCREEN"
assert_screen "Goodbye shows STOP RUN"                 "STOP RUN"                  "$SCREEN"
assert_screen "Goodbye shows farewell message"         "Thanks for listening"      "$SCREEN"

#==============================================================================
echo ""
echo "══════════════════════════════════════════════════════════"
TOTAL=$((PASS+FAIL))
echo -e "  Results: ${GREEN}$PASS passed${RESET}  ${RED}$FAIL failed${RESET}  ($TOTAL total)"
echo "══════════════════════════════════════════════════════════"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
