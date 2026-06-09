# COBPLAYR Test Suite

Tests for `podcast-player.cob` — GnuCOBOL TUI podcast player.
Covers business logic (unit) and full screen layout (tmux capture).

---

## Files

| File | What it tests | Needs |
|------|--------------|-------|
| `test-unit.sh` | Business logic: duration math, progress bar, chapter lookup, pagination, episode number extraction | `cobc` only |
| `test-screen.sh` | Full TUI screen layout vs the UI mockup: every panel, label, box-drawing char, keypress flow | `cobc` + `tmux` |

---

## Quick start

```bash
# 1. Put both scripts next to your podcast-player.cob
cp test-unit.sh test-screen.sh /path/to/your/project/
cd /path/to/your/project/

# 2. Make them executable
chmod +x test-unit.sh test-screen.sh

# 3. Run unit tests (fast, no screen, no network)
bash test-unit.sh

# 4. Run screen tests (launches the real app in tmux)
bash test-screen.sh
#   or supply a pre-compiled binary:
bash test-screen.sh ./podcast-player
```

---

## Using with Claude Code

Open your project directory in Claude Code, then just ask:

```
Run the unit tests and fix any failures.
```
```
Run test-screen.sh and tell me which UI assertions fail.
```
```
The progress bar test is failing — look at COMPUTE-PLAY-TIMES in the source and fix it.
```

Claude Code will compile, run, read the output, and iterate.

---

## What the screen tests verify (from the mockup)

```
┌─  DATA DIVISION   WORKING-STORAGE  ·  NOW-PLAYING  ─┐
│   01  SHOW-NAME   VALUE "..."       PIC X(32)        │
│   01  EP-TITLE    VALUE "..."       PIC X(72)        │
│   01  EP-NUMBER   VALUE NNN         PIC 9(03)        │
│   01  PUB-DATE    VALUE "..."       PIC X(10)        │
│   01  DURATION-SEC VALUE NNNNN  *   HH:MM:SS         │
├─  PROCEDURE DIVISION   PLAY-EPISODE                 ─┤
│   MOVE HH:MM:SS  TO  POSITION-SEC  OF  HH:MM:SS  .  │
│   [||||||||||||||||||||||||||||...............]       │
│   IF  CURRENT-CHAPTER  =  "..."   *  started  MM:SS  │
├────────────────────────────────┬─────────────────────┤
│  LINKAGE SECTION  QUEUE        │  FILE SECTION        │
│  88-LEVEL UP-NEXT              │  CHAPTER-MAP         │
│   88  EP-NNN  VALUE "..."      │  MM:SS  "..."        │
│                                │► MM:SS  "..." (active│
└────────────────────────────────┴─────────────────────┘
●   RUN     EP-NNN   ffplay -nodisp   GnuCOBOL 3.1.2
─────────────────────────────────────────────────────
*>  Press  Q  to stop        P  to play / pause
```

Each structural element above has a corresponding `assert_screen` call.

---

## Requirements

- **GnuCOBOL 3.x** — `cobc --version`
- **tmux** — `tmux -V` (screen tests only)
- **curl** — for live RSS fetch (falls back to mock data if unavailable)
- **ffplay / ffprobe** — for actual audio playback (player works without it)
- `TERM=xterm-256color` — set automatically by test-screen.sh

## Tips

- The screen tests use a **120×30 tmux window** — enough for the full UI.
- ANSI colour codes are **stripped** before assertions, so tests match text not colour.
- The RSS fetch has a 30-second curl timeout; if offline, mock data loads automatically.
- Run `test-unit.sh` first — it's instant and catches logic bugs before the slow screen tests.
