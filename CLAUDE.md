# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

```bash
cobc -free -x podcast-player.cob -o podcast-player
```

Requires GnuCOBOL 3.x (`cobc`). The `-free` flag is mandatory — source uses FREE format (not fixed 80-column).

## Run

```bash
./podcast-player
```

Runtime dependencies (must be in PATH): `curl` (RSS fetch), `ffplay` (audio playback), `ffprobe` (chapter extraction).

## Verify Changes

Compile first, then run manually to test the interactive TUI.

## Code Style

Match existing conventions in `podcast-player.cob` exactly:
- FREE format COBOL (not fixed-column)
- Working-storage variable names: `WS-` prefix, uppercase hyphenated (e.g. `WS-EPISODE-TITLE`)
- Paragraph names: uppercase hyphenated (e.g. `FETCH-RSS-FEED`)
- ANSI 256-color codes defined as level-88 condition names under `WS-COLORS`

## Architecture Notes

- Single-file source (`podcast-player.cob`, ~919 lines); do not split into multiple files
- RSS feed: fetched via `curl` → written to `feed.rss` → parsed line-by-line with UNSTRING/STRING
- Chapters: extracted via `ffprobe` → written to `chapters.json` → parsed line-by-line
- Mock fallback: 6 hardcoded episodes if RSS fetch fails; 5 hardcoded chapters if ffprobe fails
- OS detection at startup branches Windows vs Unix shell commands (`sleep`/`timeout`, `pkill`/`taskkill`)
- Fixed buffers: 2048-byte lines for RSS, 512-byte for chapters JSON — do not increase without profiling

## Podcast Source

Hardcoded to "Área de Transferência" (ADT): `https://gigahertz.fm/podcasts/adt/feed.rss`
