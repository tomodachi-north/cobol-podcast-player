>>SOURCE FORMAT IS FREE
*>================================================================
*> COBOL PODCAST PLAYER v3.0
*> Área de Transferência (ADT) - Gigahertz FM
*> IDE-themed terminal UI
*>
*> Requires: GnuCOBOL 3.x, curl, ffmpeg (ffprobe + ffplay)
*> Compile : cobc -free -x podcast-player.cob -o podcast-player
*> Run     : TERM=xterm-256color ./podcast-player
*>================================================================
IDENTIFICATION DIVISION.
PROGRAM-ID. PODCAST-PLAYER.
AUTHOR. POC-PROJECT.

ENVIRONMENT DIVISION.
INPUT-OUTPUT SECTION.
FILE-CONTROL.
    SELECT RSS-FILE  ASSIGN TO "feed.rss"      ORGANIZATION IS LINE SEQUENTIAL.
    SELECT CHAP-FILE ASSIGN TO "chapters.json" ORGANIZATION IS LINE SEQUENTIAL.
    SELECT KEY-FILE  ASSIGN TO "/tmp/cobkey.txt"
                     ORGANIZATION IS LINE SEQUENTIAL
                     FILE STATUS IS WS-KEY-STATUS.
    SELECT SIZE-FILE ASSIGN TO "/tmp/cobsize.txt"
                     ORGANIZATION IS LINE SEQUENTIAL
                     FILE STATUS IS WS-SIZE-STATUS.
    SELECT SHOWS-FILE ASSIGN TO "shows.dat"
                     ORGANIZATION IS LINE SEQUENTIAL
                     FILE STATUS IS WS-SHOWS-STATUS.

DATA DIVISION.
FILE SECTION.
FD RSS-FILE.
01 RSS-RECORD  PIC X(2048).
FD CHAP-FILE.
01 CHAP-RECORD PIC X(512).
FD KEY-FILE.
01 KEY-RECORD  PIC X(1).
FD SIZE-FILE.
01 SIZE-RECORD PIC X(20).
FD SHOWS-FILE.
01 SHOWS-RECORD PIC X(264).

WORKING-STORAGE SECTION.

*> ── ANSI Escape Sequences ──────────────────────────────────────
01 ANSI-RESET    PIC X(4)  VALUE X"1B" & "[0m".
01 ANSI-CLEAR    PIC X(7)  VALUE X"1B" & "[2J" & X"1B" & "[H".
01 ANSI-HOME     PIC X(3)  VALUE X"1B" & "[H".
01 ANSI-CLR-EOS  PIC X(3)  VALUE X"1B" & "[J".
01 ANSI-CLR-LINE PIC X(3)  VALUE X"1B" & "[K".
01 ANSI-HIDE-CUR PIC X(6)  VALUE X"1B" & "[?25l".
01 ANSI-SHOW-CUR PIC X(6)  VALUE X"1B" & "[?25h".
01 ANSI-COL-DATE PIC X(5)  VALUE X"1B" & "[65G".
01 ANSI-COL-PIC  PIC X(5)  VALUE X"1B" & "[77G".
01 ANSI-COL-87   PIC X(5)  VALUE X"1B" & "[87G".
01 ANSI-COL-88   PIC X(5)  VALUE X"1B" & "[88G".

*> 256-color palette (matched to IDE template)
*> Sized to the EXACT byte length of each escape sequence so DISPLAY
*> emits no trailing-space padding (which would shift TUI alignment).
01 C-PURPLE PIC X(11) VALUE X"1B" & "[38;5;141m".
01 C-CYAN   PIC X(10) VALUE X"1B" & "[38;5;87m".
01 C-PINK   PIC X(11) VALUE X"1B" & "[38;5;204m".
01 C-AMBER  PIC X(11) VALUE X"1B" & "[38;5;220m".
01 C-GREEN  PIC X(10) VALUE X"1B" & "[38;5;82m".
01 C-TEXT   PIC X(11) VALUE X"1B" & "[38;5;253m".
01 C-MUTED  PIC X(11) VALUE X"1B" & "[38;5;245m".
01 C-DIM    PIC X(11) VALUE X"1B" & "[38;5;238m".
01 BG-ACT   PIC X(11) VALUE X"1B" & "[48;5;236m".

*> ── OS Detection ───────────────────────────────────────────────
01 WS-OS          PIC X(10)  VALUE SPACES.
01 WS-OS-DISP     PIC X(14)  VALUE SPACES.
01 WS-WINDIR      PIC X(100) VALUE SPACES.
01 WS-SHELL       PIC X(100) VALUE SPACES.
01 WS-SLEEP-CMD   PIC X(40)  VALUE "sleep 1".
01 WS-BG-SFX      PIC X(5)   VALUE " &".
01 WS-KILL-CMD    PIC X(50)  VALUE "pkill -f ffplay 2>/dev/null".
01 WS-KEY-CMD      PIC X(200) VALUE SPACES.
01 WS-KEY-STATUS   PIC X(2)   VALUE SPACES.
01 WS-KEY-INPUT    PIC X      VALUE SPACES.

*> ── Terminal size gate ─────────────────────────────────────────
01 WS-MIN-COLS     PIC 9(4)   VALUE 90.
01 WS-MIN-ROWS     PIC 9(4)   VALUE 37.
01 WS-TERM-COLS    PIC 9(4)   VALUE 0.
01 WS-TERM-ROWS    PIC 9(4)   VALUE 0.
01 WS-SIZE-CMD     PIC X(80)  VALUE SPACES.
01 WS-SIZE-LINE    PIC X(20)  VALUE SPACES.
01 WS-SIZE-STATUS  PIC X(2)   VALUE SPACES.
01 WS-D-COLS       PIC ZZ9.
01 WS-D-ROWS       PIC ZZ9.
01 WS-D-MINC       PIC ZZ9.
01 WS-D-MINR       PIC ZZ9.

*> ── RSS Source ─────────────────────────────────────────────────
01 WS-RSS-URL PIC X(200)
    VALUE "https://gigahertz.fm/podcasts/adt/feed.rss".

*> ── Podcast Shows (persisted in shows.dat) ─────────────────────
01 WS-MAX-SHOW   PIC 99 VALUE 12.
01 WS-SHOW-CNT   PIC 99 VALUE 0.
01 WS-SHOWS.
    05 WS-SHOW OCCURS 12 TIMES.
        10 WS-SHOW-NAME PIC X(60).
        10 WS-SHOW-URL  PIC X(200).
01 WS-SHOWS-STATUS PIC X(2) VALUE SPACES.
01 WS-NEW-URL    PIC X(200) VALUE SPACES.
01 WS-SHOW-SEL   PIC X(5)   VALUE SPACES.
01 WS-SHOW-NUM   PIC 99     VALUE 0.
01 WS-SHOW-IDX   PIC 99     VALUE 0.
01 WS-DEL-STATE  PIC 9      VALUE 0.
01 WS-DEL-IDX    PIC 99     VALUE 0.
01 WS-EP-CONTINUE PIC X     VALUE "Y".
01 WS-VALIDATE-OK PIC X     VALUE "N".

*> ── Episode Storage (up to 50) ─────────────────────────────────
01 WS-MAX-EP  PIC 99 VALUE 50.
01 WS-EP-CNT  PIC 99 VALUE 0.
01 WS-EPISODES.
    05 WS-EP OCCURS 50 TIMES.
        10 WS-EP-NUM    PIC X(3).
        10 WS-EP-TITLE  PIC X(150).
        10 WS-EP-URL    PIC X(512).
        10 WS-EP-DATE   PIC X(35).
        10 WS-EP-DUR    PIC X(20).
        10 WS-EP-DURSEC PIC 9(5) VALUE 0.

*> ── Chapter Storage (up to 10) ─────────────────────────────────
01 WS-MAX-CH  PIC 99 VALUE 10.
01 WS-CH-CNT  PIC 99 VALUE 0.
01 WS-CHAPTERS.
    05 WS-CH OCCURS 10 TIMES.
        10 WS-CH-SEC   PIC 9(5) VALUE 0.
        10 WS-CH-TS    PIC X(5) VALUE SPACES.
        10 WS-CH-TITLE PIC X(60) VALUE SPACES.

*> ── RSS Parser ─────────────────────────────────────────────────
01 WS-IN-ITEM    PIC X VALUE "N".
01 WS-CURR-TTL   PIC X(150) VALUE SPACES.
01 WS-CURR-URL   PIC X(512) VALUE SPACES.
01 WS-CURR-DATE  PIC X(35)  VALUE SPACES.
01 WS-CURR-DUR   PIC X(20)  VALUE SPACES.
01 WS-EOF        PIC X VALUE "N".
01 WS-LINE       PIC X(2048) VALUE SPACES.
01 WS-PART-A     PIC X(2048) VALUE SPACES.
01 WS-PART-B     PIC X(2048) VALUE SPACES.
01 WS-PART-C     PIC X(2048) VALUE SPACES.
01 WS-SCAN-POS   PIC 9(4) VALUE 0.
01 WS-NUM-RAW    PIC X(10) VALUE SPACES.
01 WS-NUM-IDX    PIC 99 VALUE 0.
01 WS-NUM-OUT    PIC 99 VALUE 0.
01 WS-CHAR       PIC X VALUE SPACES.
01 WS-CURR-EPNUM PIC X(10) VALUE SPACES.
01 WS-ANY-EPNUM  PIC X VALUE "N".
01 WS-SCAN-SRC   PIC X(150) VALUE SPACES.
01 WS-POS-NUM    PIC 999 VALUE 0.

*> ── Chapter Parser ─────────────────────────────────────────────
01 WS-CHAP-LINE    PIC X(512) VALUE SPACES.
01 WS-CHAP-EOF     PIC X VALUE "N".
01 WS-CURR-CHSEC   PIC 9(5) VALUE 0.
01 WS-CURR-CHTITL  PIC X(60) VALUE SPACES.
01 WS-CH-INT-PART  PIC X(10) VALUE SPACES.
01 WS-CH-MM        PIC 99 VALUE 0.
01 WS-CH-SS        PIC 99 VALUE 0.

*> ── Duration parsing ───────────────────────────────────────────
01 WS-DUR-HH PIC 99 VALUE 0.
01 WS-DUR-MM PIC 99 VALUE 0.
01 WS-DUR-SS PIC 99 VALUE 0.

*> ── Pagination ──────────────────────────────────────────────────
01 WS-PAGE-SIZE   PIC 99 VALUE 12.
01 WS-PAGE-NUM    PIC 99 VALUE 1.
01 WS-PAGE-START  PIC 99 VALUE 1.
01 WS-PAGE-END    PIC 99 VALUE 12.
01 WS-PAGE-ITEMS  PIC 99 VALUE 0.
01 WS-MSG         PIC X(70) VALUE SPACES.

*> ── UI State ───────────────────────────────────────────────────
01 WS-SELECTION  PIC X(5) VALUE SPACES.
01 WS-SEL-NUM   PIC 99 VALUE 0.
01 WS-CONTINUE  PIC X VALUE "Y".
01 WS-PLAYING   PIC 99 VALUE 0.
01 WS-DISP-IDX  PIC 99 VALUE 0.
01 WS-IDX-2D    PIC 99 VALUE 0.
01 WS-CH-START  PIC 99 VALUE 1.
01 WS-CH-IDX    PIC 99 VALUE 0.
01 WS-TITLE-50  PIC X(50) VALUE SPACES.
01 WS-TITLE-30  PIC X(30) VALUE SPACES.
01 WS-DATE-16   PIC X(16) VALUE SPACES.
01 WS-TITLE-18  PIC X(18) VALUE SPACES.
01 WS-STATUS    PIC X(60) VALUE SPACES.

*> ── UTF-8 aware cell formatter (display-column based) ───────────
01 WS-FMT-IN    PIC X(150) VALUE SPACES.
01 WS-FMT-OUT   PIC X(160) VALUE SPACES.
01 WS-FMT-WANT  PIC 999 VALUE 0.
01 WS-FMT-COLS  PIC 999 VALUE 0.
01 WS-FMT-IPOS  PIC 999 VALUE 0.
01 WS-FMT-OPOS  PIC 999 VALUE 0.
01 WS-FMT-BYTE  PIC X VALUE SPACE.
01 WS-FMT-ORD   PIC 999 VALUE 0.
01 WS-FMT-CW    PIC 9 VALUE 1.
01 WS-FMT-LEN   PIC 999 VALUE 0.

*> ── Box-interior centering (cols 5..87 = 83 display columns) ────
01 WS-PAD        PIC X(83) VALUE SPACES.
01 WS-CENTER-PAD PIC 999 VALUE 0.
01 WS-FETCH-OK  PIC X VALUE "N".
01 WS-CHAP-OK   PIC X VALUE "N".

*> ── Playback / Time ────────────────────────────────────────────
01 WS-START-TIME.
    05 WS-ST-HH PIC 99.
    05 WS-ST-MM PIC 99.
    05 WS-ST-SS PIC 99.
    05 WS-ST-CC PIC 99.
01 WS-CURR-TIME.
    05 WS-CT-HH PIC 99.
    05 WS-CT-MM PIC 99.
    05 WS-CT-SS PIC 99.
    05 WS-CT-CC PIC 99.
01 WS-ELAPSED-SEC  PIC 9(5) VALUE 0.
01 WS-DURATION-SEC PIC 9(5) VALUE 0.
*> ── Seek (forward / back) ──────────────────────────────────────
01 WS-SEEK-BASE    PIC 9(5) VALUE 0.   *> ffplay start offset (sec)
01 WS-SEEK-POS     PIC 9(5) VALUE 0.   *> computed seek target
01 WS-SEEK-DISP    PIC Z(4)9.          *> -ss arg, no leading zeros
01 WS-ACTIVE-CHAP  PIC 99 VALUE 1.
01 WS-STOP-FLAG    PIC X VALUE "N".
01 WS-UI-DRAWN    PIC X VALUE "N".
01 WS-PAUSED       PIC X VALUE "N".
01 WS-PAUSE-TIME.
    05 WS-PT-HH    PIC 99.
    05 WS-PT-MM    PIC 99.
    05 WS-PT-SS    PIC 99.
    05 WS-PT-CC    PIC 99.
01 WS-TOTAL-PAUSED PIC 9(5) VALUE 0.
01 WS-PAUSE-CMD    PIC X(60) VALUE SPACES.
01 WS-RESUME-CMD   PIC X(60) VALUE SPACES.

*> ── Progress bar display ───────────────────────────────────────
01 WS-BAR-WIDTH  PIC 99 VALUE 65.
01 WS-BAR-FILLED PIC 99 VALUE 0.
01 WS-BAR-EMPTY  PIC 99 VALUE 0.
01 WS-BAR-IDX    PIC 99 VALUE 0.
01 WS-EL-HH      PIC 99 VALUE 0.
01 WS-EL-MM      PIC 99 VALUE 0.
01 WS-EL-SS      PIC 99 VALUE 0.
01 WS-EL-TEMP    PIC 9(5) VALUE 0.

*> ── Waveform rendering ─────────────────────────────────────────
01 WS-WAVE-WIDTH PIC 99 VALUE 55.
01 WS-WAVE-POS   PIC 99 VALUE 0.
01 WS-MKPOS      PIC 99 VALUE 0.
01 WS-DASH-CNT   PIC 99 VALUE 0.
01 WS-DASH-IDX   PIC 99 VALUE 0.
01 WS-WAVE-IDX   PIC 99 VALUE 0.
01 WS-BAR-LINE   PIC X(70) VALUE SPACES.

*> ── Command / shell ────────────────────────────────────────────
01 WS-CMD          PIC X(700) VALUE SPACES.
01 WS-RETURN-CODE  PIC 99 VALUE 0.

*> ── Date/time display ──────────────────────────────────────────
01 WS-DATE-DISP PIC X(10) VALUE SPACES.
01 WS-TIME-DISP PIC X(8)  VALUE SPACES.
01 WS-DATE-ACC  PIC X(8)  VALUE SPACES.
01 WS-TIME-ACC  PIC X(6)  VALUE SPACES.

*> ── Mock CPU / NET stats (flicker for realism) ─────────────────
01 WS-CPU-A PIC 9 VALUE 1.
01 WS-CPU-B PIC 9 VALUE 2.
01 WS-NET   PIC 99 VALUE 42.

PROCEDURE DIVISION.

*>================================================================
MAIN-LOGIC.
*>================================================================
    PERFORM DETECT-OS
    PERFORM CHECK-TERMINAL-SIZE
    PERFORM GET-DATE-TIME
    PERFORM SHOW-SPLASH
    PERFORM LOAD-SHOWS
    PERFORM UNTIL WS-CONTINUE = "N"
        PERFORM SHOW-PODCAST-BROWSER
        PERFORM HANDLE-PODCAST-INPUT
    END-PERFORM
    PERFORM CLEANUP-AND-EXIT
    DISPLAY ANSI-SHOW-CUR
    STOP RUN.

*>================================================================
DETECT-OS.
*>================================================================
    ACCEPT WS-WINDIR FROM ENVIRONMENT "WINDIR"
    ACCEPT WS-SHELL  FROM ENVIRONMENT "SHELL"
    EVALUATE TRUE
        WHEN WS-WINDIR NOT = SPACES
            MOVE "Windows"        TO WS-OS
            MOVE "WIN32"          TO WS-OS-DISP
            MOVE "timeout /t 1 /nobreak > nul 2>&1" TO WS-SLEEP-CMD
            MOVE " & exit"        TO WS-BG-SFX
            MOVE "taskkill /IM ffplay.exe /F > nul 2>&1" TO WS-KILL-CMD
            MOVE "timeout /t 1 /nobreak > nul 2>&1" TO WS-KEY-CMD
        WHEN WS-SHELL NOT = SPACES
            MOVE "Unix"           TO WS-OS
            MOVE "LINUX-X86-64"   TO WS-OS-DISP
            MOVE "sleep 1"        TO WS-SLEEP-CMD
            MOVE " &"             TO WS-BG-SFX
            MOVE "pkill -9 ffplay 2>/dev/null" TO WS-KILL-CMD
            MOVE "pkill -STOP ffplay 2>/dev/null" TO WS-PAUSE-CMD
            MOVE "pkill -CONT ffplay 2>/dev/null" TO WS-RESUME-CMD
            MOVE "stty size </dev/tty >/tmp/cobsize.txt 2>/dev/null"
                TO WS-SIZE-CMD
            STRING
                "bash -c 'read -t 1 -s -n 1 K </dev/tty 2>/dev/null;"
                " case "
                X"22" "$K" X"22"
                " in q|Q)echo 1;;p|P)echo 3;;f|F)echo 4;;"
                "b|B)echo 5;;*)echo 0;;esac"
                " >/tmp/cobkey.txt'"
                DELIMITED SIZE INTO WS-KEY-CMD
        WHEN OTHER
            MOVE "Unknown"        TO WS-OS
            MOVE "UNKNOWN"        TO WS-OS-DISP
    END-EVALUATE.

*>================================================================
CHECK-TERMINAL-SIZE.
*>================================================================
*>  If the window is smaller than WS-MIN-COLS x WS-MIN-ROWS the TUI
*>  cannot render, so show a warning and exit automatically.
    PERFORM GET-TERM-SIZE
    IF WS-TERM-COLS < WS-MIN-COLS
    OR WS-TERM-ROWS < WS-MIN-ROWS
        PERFORM SHOW-SIZE-WARNING
*>      Keep the message on screen long enough to read, then exit.
        PERFORM 4 TIMES
            CALL "SYSTEM" USING WS-SLEEP-CMD
        END-PERFORM
        DISPLAY ANSI-SHOW-CUR
        STOP RUN
    END-IF.

*>================================================================
GET-TERM-SIZE.
*>================================================================
*>  "stty size" prints "<rows> <cols>"; non-Unix shells cannot be
*>  measured this way, so assume they are big enough.
    IF WS-OS = "Unix"
        MOVE 0 TO WS-TERM-ROWS
        MOVE 0 TO WS-TERM-COLS
        CALL "SYSTEM" USING WS-SIZE-CMD
        OPEN INPUT SIZE-FILE
        IF WS-SIZE-STATUS = "00"
            READ SIZE-FILE INTO WS-SIZE-LINE
                AT END CONTINUE
            END-READ
            CLOSE SIZE-FILE
            UNSTRING WS-SIZE-LINE DELIMITED BY ALL SPACES
                INTO WS-TERM-ROWS WS-TERM-COLS
        END-IF
    ELSE
        MOVE 999 TO WS-TERM-ROWS
        MOVE 999 TO WS-TERM-COLS
    END-IF.

*>================================================================
SHOW-SIZE-WARNING.
*>================================================================
    MOVE WS-TERM-COLS TO WS-D-COLS
    MOVE WS-TERM-ROWS TO WS-D-ROWS
    MOVE WS-MIN-COLS  TO WS-D-MINC
    MOVE WS-MIN-ROWS  TO WS-D-MINR
    DISPLAY ANSI-CLEAR
    DISPLAY " "
    DISPLAY "   " C-PINK "*> TERMINAL TOO SMALL" ANSI-RESET
    DISPLAY " "
    DISPLAY "   " C-TEXT "This player needs at least "
            C-CYAN FUNCTION TRIM(WS-D-MINC) C-TEXT " columns x "
            C-CYAN FUNCTION TRIM(WS-D-MINR) C-TEXT " rows to render."
            ANSI-RESET
    DISPLAY "   " C-MUTED "Current size: "
            C-AMBER FUNCTION TRIM(WS-D-COLS) C-MUTED " x "
            C-AMBER FUNCTION TRIM(WS-D-ROWS) ANSI-RESET
    DISPLAY " "
    DISPLAY "   " C-MUTED "Resize the window and run again." ANSI-RESET
    DISPLAY " ".

*>================================================================
GET-DATE-TIME.
*>================================================================
    ACCEPT WS-DATE-ACC FROM DATE YYYYMMDD
    STRING WS-DATE-ACC(1:4) "-" WS-DATE-ACC(5:2) "-" WS-DATE-ACC(7:2)
        DELIMITED SIZE INTO WS-DATE-DISP
    ACCEPT WS-TIME-ACC FROM TIME
    STRING WS-TIME-ACC(1:2) ":" WS-TIME-ACC(3:2) ":" WS-TIME-ACC(5:2)
        DELIMITED SIZE INTO WS-TIME-DISP.

*>================================================================
SHOW-SPLASH.
*>================================================================
    DISPLAY ANSI-CLEAR ANSI-HIDE-CUR
    DISPLAY " "
    DISPLAY "  " C-PURPLE "IDENTIFICATION DIVISION" C-DIM "." ANSI-RESET
    DISPLAY "  " C-MUTED "PROGRAM-ID" C-DIM ". " C-CYAN "COBPLAYR" C-DIM "." ANSI-RESET
    DISPLAY " "
    DISPLAY "  " C-CYAN ">>> " C-TEXT "Loading RSS feed and initializing..."
            ANSI-RESET.

*>================================================================
FETCH-RSS-FEED.
*>================================================================
    MOVE SPACES TO WS-CMD
    STRING "curl -s -L --max-time 30 -o feed.rss "
        DELIMITED SIZE
        FUNCTION TRIM(WS-RSS-URL TRAILING)
        DELIMITED SIZE
        INTO WS-CMD
    CALL "SYSTEM" USING WS-CMD RETURNING WS-RETURN-CODE.

*>================================================================
PARSE-RSS-FEED.
*>================================================================
    MOVE "N" TO WS-EOF WS-IN-ITEM WS-ANY-EPNUM
    MOVE 0   TO WS-EP-CNT
    OPEN INPUT RSS-FILE
    PERFORM UNTIL WS-EOF = "Y" OR WS-EP-CNT >= WS-MAX-EP
        READ RSS-FILE INTO WS-LINE
            AT END MOVE "Y" TO WS-EOF
            NOT AT END PERFORM PROCESS-RSS-LINE
        END-READ
    END-PERFORM
    CLOSE RSS-FILE
    IF WS-ANY-EPNUM = "N" AND WS-EP-CNT > 0
        PERFORM ASSIGN-POSITIONAL-NUMBERS
    END-IF.

*>  No episode in the feed exposed a real number — number them by
*>  reverse parse order so the newest (index 1) gets the highest.
ASSIGN-POSITIONAL-NUMBERS.
    PERFORM VARYING WS-NUM-IDX FROM 1 BY 1 UNTIL WS-NUM-IDX > WS-EP-CNT
        COMPUTE WS-POS-NUM = WS-EP-CNT - WS-NUM-IDX + 1
        MOVE WS-POS-NUM TO WS-EP-NUM(WS-NUM-IDX)
    END-PERFORM.

PROCESS-RSS-LINE.
    PERFORM CHECK-ITEM-OPEN
    PERFORM CHECK-ITEM-CLOSE
    IF WS-IN-ITEM = "Y"
        IF WS-CURR-TTL   = SPACES PERFORM EXTRACT-TITLE      END-IF
        IF WS-CURR-URL   = SPACES PERFORM EXTRACT-URL        END-IF
        IF WS-CURR-DATE  = SPACES PERFORM EXTRACT-DATE       END-IF
        IF WS-CURR-DUR   = SPACES PERFORM EXTRACT-DUR        END-IF
        IF WS-CURR-EPNUM = SPACES PERFORM EXTRACT-EPNUM-TAG  END-IF
    END-IF.

CHECK-ITEM-OPEN.
    MOVE 0 TO WS-SCAN-POS
    INSPECT WS-LINE TALLYING WS-SCAN-POS FOR CHARACTERS BEFORE INITIAL "<item>"
    IF WS-SCAN-POS + 6 <= 2048 AND WS-LINE(WS-SCAN-POS + 1:6) = "<item>"
        MOVE "Y"    TO WS-IN-ITEM
        MOVE SPACES TO WS-CURR-EPNUM
        MOVE SPACES TO WS-CURR-TTL WS-CURR-URL WS-CURR-DATE WS-CURR-DUR
    END-IF.

CHECK-ITEM-CLOSE.
    MOVE 0 TO WS-SCAN-POS
    INSPECT WS-LINE TALLYING WS-SCAN-POS FOR CHARACTERS BEFORE INITIAL "</item>"
    IF WS-SCAN-POS + 7 <= 2048 AND WS-LINE(WS-SCAN-POS + 1:7) = "</item>"
        IF WS-IN-ITEM = "Y" AND WS-CURR-TTL NOT = SPACES
                            AND WS-CURR-URL NOT = SPACES
            ADD 1 TO WS-EP-CNT
            MOVE FUNCTION TRIM(WS-CURR-TTL  TRAILING) TO WS-EP-TITLE(WS-EP-CNT)
            MOVE FUNCTION TRIM(WS-CURR-URL  TRAILING) TO WS-EP-URL(WS-EP-CNT)
            MOVE FUNCTION TRIM(WS-CURR-DATE TRAILING) TO WS-EP-DATE(WS-EP-CNT)
            MOVE FUNCTION TRIM(WS-CURR-DUR  TRAILING) TO WS-EP-DUR(WS-EP-CNT)
            PERFORM EXTRACT-EP-NUMBER
            PERFORM STRIP-TITLE-PREFIX
            PERFORM PARSE-DURATION
        END-IF
        MOVE "N" TO WS-IN-ITEM
    END-IF.

*>  Determine the episode number, in priority order:
*>    1. <itunes:episode> tag value
*>    2. number after " #" in the title  (e.g. "... no Ar #684:")
*>    3. leading digits of the title      (e.g. "480: ...")
*>  A whole-feed positional fallback (ASSIGN-POSITIONAL-NUMBERS) runs
*>  later if no episode yielded a real number.
EXTRACT-EP-NUMBER.
    MOVE SPACES TO WS-SCAN-SRC
    IF WS-CURR-EPNUM NOT = SPACES
        MOVE FUNCTION TRIM(WS-CURR-EPNUM) TO WS-SCAN-SRC
    ELSE
        MOVE SPACES TO WS-PART-A WS-PART-B
        UNSTRING WS-CURR-TTL DELIMITED BY " #"
            INTO WS-PART-A WS-PART-B
        IF WS-PART-B NOT = SPACES
            MOVE WS-PART-B TO WS-SCAN-SRC
        ELSE
            MOVE WS-CURR-TTL TO WS-SCAN-SRC
        END-IF
    END-IF
    PERFORM SCAN-LEADING-DIGITS
    IF WS-NUM-OUT > 0
        MOVE WS-NUM-RAW(1:3) TO WS-EP-NUM(WS-EP-CNT)
        MOVE "Y" TO WS-ANY-EPNUM
    ELSE
        MOVE "---" TO WS-EP-NUM(WS-EP-CNT)
    END-IF.

*>  Collect up to 3 digits from the first 5 chars of WS-SCAN-SRC.
SCAN-LEADING-DIGITS.
    MOVE SPACES TO WS-NUM-RAW
    MOVE 0 TO WS-NUM-OUT
    PERFORM VARYING WS-NUM-IDX FROM 1 BY 1
        UNTIL WS-NUM-IDX > 5 OR WS-NUM-OUT >= 3
        MOVE WS-SCAN-SRC(WS-NUM-IDX:1) TO WS-CHAR
        IF WS-CHAR >= "0" AND WS-CHAR <= "9"
            ADD 1 TO WS-NUM-OUT
            MOVE WS-CHAR TO WS-NUM-RAW(WS-NUM-OUT:1)
        END-IF
    END-PERFORM.

*>  Capture <itunes:episode>NNN</itunes:episode> (does not match the
*>  unrelated <itunes:episodeType> tag — the delimiter needs the '>').
EXTRACT-EPNUM-TAG.
    MOVE SPACES TO WS-PART-A WS-PART-B
    UNSTRING WS-LINE DELIMITED BY "<itunes:episode>"
        INTO WS-PART-A WS-PART-B
    IF WS-PART-B NOT = SPACES
        MOVE SPACES TO WS-CURR-EPNUM WS-PART-A
        UNSTRING WS-PART-B DELIMITED BY "</itunes:episode>"
            INTO WS-CURR-EPNUM WS-PART-A
        MOVE FUNCTION TRIM(WS-CURR-EPNUM) TO WS-CURR-EPNUM
    END-IF.

EXTRACT-TITLE.
    MOVE SPACES TO WS-PART-A WS-PART-B
    UNSTRING WS-LINE DELIMITED BY "<title>" INTO WS-PART-A WS-PART-B
    IF WS-PART-B NOT = SPACES
        MOVE SPACES TO WS-CURR-TTL WS-PART-A
        UNSTRING WS-PART-B DELIMITED BY "</title>" INTO WS-CURR-TTL WS-PART-A
        MOVE FUNCTION TRIM(WS-CURR-TTL LEADING) TO WS-CURR-TTL
        PERFORM STRIP-CDATA
    END-IF.

STRIP-CDATA.
    MOVE SPACES TO WS-PART-A WS-PART-B
    UNSTRING WS-CURR-TTL DELIMITED BY "<![CDATA[" INTO WS-PART-A WS-PART-B
    IF WS-PART-B NOT = SPACES
        MOVE SPACES TO WS-CURR-TTL WS-PART-A
        UNSTRING WS-PART-B DELIMITED BY "]]>" INTO WS-CURR-TTL WS-PART-A
        MOVE FUNCTION TRIM(WS-CURR-TTL TRAILING) TO WS-CURR-TTL
    END-IF.

EXTRACT-URL.
    MOVE SPACES TO WS-PART-A WS-PART-B
    UNSTRING WS-LINE DELIMITED BY "<enclosure" INTO WS-PART-A WS-PART-B
    IF WS-PART-B NOT = SPACES
        MOVE SPACES TO WS-PART-A WS-PART-C
        UNSTRING WS-PART-B DELIMITED BY 'url="' INTO WS-PART-A WS-PART-C
        IF WS-PART-C NOT = SPACES
            MOVE SPACES TO WS-CURR-URL WS-PART-A
            UNSTRING WS-PART-C DELIMITED BY '"' INTO WS-CURR-URL WS-PART-A
            IF WS-CURR-URL(1:2) = "//"
                MOVE FUNCTION TRIM(WS-CURR-URL TRAILING) TO WS-PART-C
                MOVE SPACES TO WS-CURR-URL
                STRING "https:" DELIMITED SIZE
                       FUNCTION TRIM(WS-PART-C TRAILING) DELIMITED SIZE
                       INTO WS-CURR-URL
            END-IF
        END-IF
    END-IF.

EXTRACT-DATE.
    MOVE SPACES TO WS-PART-A WS-PART-B
    UNSTRING WS-LINE DELIMITED BY "<pubDate>" INTO WS-PART-A WS-PART-B
    IF WS-PART-B NOT = SPACES
        MOVE SPACES TO WS-CURR-DATE WS-PART-A
        UNSTRING WS-PART-B DELIMITED BY "</pubDate>" INTO WS-CURR-DATE WS-PART-A
        MOVE FUNCTION TRIM(WS-CURR-DATE TRAILING) TO WS-CURR-DATE
    END-IF.

EXTRACT-DUR.
    MOVE SPACES TO WS-PART-A WS-PART-B
    UNSTRING WS-LINE DELIMITED BY "<itunes:duration>" INTO WS-PART-A WS-PART-B
    IF WS-PART-B NOT = SPACES
        MOVE SPACES TO WS-CURR-DUR WS-PART-A
        UNSTRING WS-PART-B DELIMITED BY "</itunes:duration>" INTO WS-CURR-DUR WS-PART-A
        MOVE FUNCTION TRIM(WS-CURR-DUR TRAILING) TO WS-CURR-DUR
    END-IF.

PARSE-DURATION.
    MOVE 0 TO WS-EP-DURSEC(WS-EP-CNT) WS-DUR-HH WS-DUR-MM WS-DUR-SS
    MOVE SPACES TO WS-PART-A WS-PART-B WS-PART-C
    UNSTRING WS-EP-DUR(WS-EP-CNT) DELIMITED BY ":"
        INTO WS-PART-A WS-PART-B WS-PART-C
    IF WS-PART-C NOT = SPACES
        MOVE FUNCTION NUMVAL(WS-PART-A) TO WS-DUR-HH
        MOVE FUNCTION NUMVAL(WS-PART-B) TO WS-DUR-MM
        MOVE FUNCTION NUMVAL(WS-PART-C) TO WS-DUR-SS
        COMPUTE WS-EP-DURSEC(WS-EP-CNT) =
            WS-DUR-HH * 3600 + WS-DUR-MM * 60 + WS-DUR-SS
    ELSE IF WS-PART-B NOT = SPACES
        MOVE FUNCTION NUMVAL(WS-PART-A) TO WS-DUR-MM
        MOVE FUNCTION NUMVAL(WS-PART-B) TO WS-DUR-SS
        COMPUTE WS-EP-DURSEC(WS-EP-CNT) = WS-DUR-MM * 60 + WS-DUR-SS
    ELSE
        MOVE FUNCTION NUMVAL(WS-PART-A) TO WS-EP-DURSEC(WS-EP-CNT)
    END-IF.

STRIP-TITLE-PREFIX.
    MOVE SPACES TO WS-PART-A WS-PART-B
    UNSTRING WS-EP-TITLE(WS-EP-CNT) DELIMITED BY ": "
        INTO WS-PART-A WS-PART-B
    IF WS-PART-B NOT = SPACES
        IF WS-PART-A(1:1) >= "0" AND WS-PART-A(1:1) <= "9"
            MOVE FUNCTION TRIM(WS-PART-B TRAILING)
                TO WS-EP-TITLE(WS-EP-CNT)
        END-IF
    END-IF.

LOAD-MOCK-DATA.
    MOVE 6 TO WS-EP-CNT
    MOVE "413" TO WS-EP-NUM(1)
    MOVE "Uma Meta Morfose"               TO WS-EP-TITLE(1)
    MOVE "Fri, 17 Jan 2025"               TO WS-EP-DATE(1)
    MOVE "00:58:40"                        TO WS-EP-DUR(1)
    MOVE 3520                              TO WS-EP-DURSEC(1)
    MOVE "412" TO WS-EP-NUM(2)
    MOVE "O Futuro da Apple"              TO WS-EP-TITLE(2)
    MOVE "Fri, 10 Jan 2025"               TO WS-EP-DATE(2)
    MOVE "00:52:10"                        TO WS-EP-DUR(2)
    MOVE 3130                              TO WS-EP-DURSEC(2)
    MOVE "411" TO WS-EP-NUM(3)
    MOVE "IA no Brasil"                   TO WS-EP-TITLE(3)
    MOVE "Fri, 03 Jan 2025"               TO WS-EP-DATE(3)
    MOVE "00:47:35"                        TO WS-EP-DUR(3)
    MOVE 2855                              TO WS-EP-DURSEC(3)
    MOVE "410" TO WS-EP-NUM(4)
    MOVE "Retro 2024"                     TO WS-EP-TITLE(4)
    MOVE "Fri, 27 Dec 2024"               TO WS-EP-DATE(4)
    MOVE "00:58:20"                        TO WS-EP-DUR(4)
    MOVE 3500                              TO WS-EP-DURSEC(4)
    MOVE "409" TO WS-EP-NUM(5)
    MOVE "O Ano em Review"                TO WS-EP-TITLE(5)
    MOVE "Fri, 20 Dec 2024"               TO WS-EP-DATE(5)
    MOVE "01:02:15"                        TO WS-EP-DUR(5)
    MOVE 3735                              TO WS-EP-DURSEC(5)
    MOVE "408" TO WS-EP-NUM(6)
    MOVE "Privacidade Digital"            TO WS-EP-TITLE(6)
    MOVE "Fri, 13 Dec 2024"               TO WS-EP-DATE(6)
    MOVE "00:55:00"                        TO WS-EP-DUR(6)
    MOVE 3300                              TO WS-EP-DURSEC(6).

*>================================================================
*>   CHAPTER EXTRACTION & PARSING
*>================================================================

EXTRACT-CHAPTERS.
    MOVE 0 TO WS-CH-CNT
    MOVE "N" TO WS-CHAP-OK
    IF WS-EP-URL(WS-PLAYING) = SPACES
        PERFORM LOAD-MOCK-CHAPTERS
        EXIT PARAGRAPH
    END-IF
    MOVE SPACES TO WS-CMD
    STRING "ffprobe -v quiet -print_format json -show_chapters "
        DELIMITED SIZE
        X"22" FUNCTION TRIM(WS-EP-URL(WS-PLAYING) TRAILING) X"22"
        DELIMITED SIZE
        " > chapters.json 2>/dev/null"
        DELIMITED SIZE
        INTO WS-CMD
    CALL "SYSTEM" USING WS-CMD RETURNING WS-RETURN-CODE
    PERFORM PARSE-CHAPTERS-FILE
    IF WS-CH-CNT = 0
        PERFORM LOAD-MOCK-CHAPTERS
    ELSE
        MOVE "Y" TO WS-CHAP-OK
    END-IF.

PARSE-CHAPTERS-FILE.
    MOVE 0   TO WS-CH-CNT
    MOVE "N" TO WS-CHAP-EOF
    MOVE 0 TO WS-CURR-CHSEC
    MOVE SPACES TO WS-CURR-CHTITL
    OPEN INPUT CHAP-FILE
    PERFORM UNTIL WS-CHAP-EOF = "Y" OR WS-CH-CNT >= WS-MAX-CH
        READ CHAP-FILE INTO WS-CHAP-LINE
            AT END MOVE "Y" TO WS-CHAP-EOF
            NOT AT END PERFORM PROCESS-CHAP-LINE
        END-READ
    END-PERFORM
    CLOSE CHAP-FILE.

PROCESS-CHAP-LINE.
    MOVE SPACES TO WS-PART-A WS-PART-B
    UNSTRING WS-CHAP-LINE DELIMITED BY '"start_time": "'
        INTO WS-PART-A WS-PART-B
    IF WS-PART-B NOT = SPACES
        MOVE SPACES TO WS-CH-INT-PART WS-PART-A
        UNSTRING WS-PART-B DELIMITED BY "."
            INTO WS-CH-INT-PART WS-PART-A
        MOVE FUNCTION NUMVAL(WS-CH-INT-PART) TO WS-CURR-CHSEC
    END-IF

    MOVE SPACES TO WS-PART-A WS-PART-B
    UNSTRING WS-CHAP-LINE DELIMITED BY '"title": "'
        INTO WS-PART-A WS-PART-B
    IF WS-PART-B NOT = SPACES AND WS-CURR-CHSEC >= 0
        MOVE SPACES TO WS-CURR-CHTITL WS-PART-A
        UNSTRING WS-PART-B DELIMITED BY '"'
            INTO WS-CURR-CHTITL WS-PART-A
        ADD 1 TO WS-CH-CNT
        MOVE WS-CURR-CHSEC TO WS-CH-SEC(WS-CH-CNT)
        MOVE FUNCTION TRIM(WS-CURR-CHTITL TRAILING)
            TO WS-CH-TITLE(WS-CH-CNT)
        PERFORM FORMAT-CH-TIMESTAMP
        MOVE SPACES TO WS-CURR-CHTITL
        MOVE 0      TO WS-CURR-CHSEC
    END-IF.

FORMAT-CH-TIMESTAMP.
    COMPUTE WS-CH-MM = WS-CH-SEC(WS-CH-CNT) / 60
    COMPUTE WS-CH-SS = WS-CH-SEC(WS-CH-CNT) - WS-CH-MM * 60
    STRING WS-CH-MM ":" WS-CH-SS
        DELIMITED SIZE INTO WS-CH-TS(WS-CH-CNT).

LOAD-MOCK-CHAPTERS.
    MOVE 5 TO WS-CH-CNT
    MOVE 0    TO WS-CH-SEC(1)   MOVE "00:00" TO WS-CH-TS(1)
    MOVE "Frio Cortante"         TO WS-CH-TITLE(1)
    MOVE 390  TO WS-CH-SEC(2)   MOVE "06:30" TO WS-CH-TS(2)
    MOVE "Tema Principal"        TO WS-CH-TITLE(2)
    MOVE 1320 TO WS-CH-SEC(3)   MOVE "22:00" TO WS-CH-TS(3)
    MOVE "Debate e Analise"      TO WS-CH-TITLE(3)
    MOVE 2460 TO WS-CH-SEC(4)   MOVE "41:00" TO WS-CH-TS(4)
    MOVE "Dev e Mercado BR"      TO WS-CH-TITLE(4)
    MOVE 3180 TO WS-CH-SEC(5)   MOVE "53:00" TO WS-CH-TS(5)
    MOVE "Encerramento"          TO WS-CH-TITLE(5).

*>================================================================
*>   PODCAST SHOW BROWSER (home screen)
*>================================================================

*>  Load the persisted show list from shows.dat. The repo ships this
*>  file with the default ADT show; if it is missing/empty we seed it
*>  and write it back (self-healing).
LOAD-SHOWS.
    MOVE 0 TO WS-SHOW-CNT
    OPEN INPUT SHOWS-FILE
    IF WS-SHOWS-STATUS = "00"
        PERFORM READ-SHOW-RECORD
        PERFORM UNTIL WS-SHOWS-STATUS NOT = "00"
                   OR WS-SHOW-CNT >= WS-MAX-SHOW
            IF SHOWS-RECORD NOT = SPACES
                ADD 1 TO WS-SHOW-CNT
                UNSTRING SHOWS-RECORD DELIMITED BY "|"
                    INTO WS-SHOW-NAME(WS-SHOW-CNT)
                         WS-SHOW-URL(WS-SHOW-CNT)
            END-IF
            PERFORM READ-SHOW-RECORD
        END-PERFORM
        CLOSE SHOWS-FILE
    END-IF
    IF WS-SHOW-CNT = 0
        PERFORM SEED-SHOWS
        PERFORM SAVE-SHOWS
    END-IF.

READ-SHOW-RECORD.
    READ SHOWS-FILE
        AT END CONTINUE
    END-READ.

SEED-SHOWS.
    MOVE 1 TO WS-SHOW-CNT
    MOVE "Área de Transferência" TO WS-SHOW-NAME(1)
    MOVE "https://gigahertz.fm/podcasts/adt/feed.rss"
        TO WS-SHOW-URL(1).

SAVE-SHOWS.
    OPEN OUTPUT SHOWS-FILE
    PERFORM VARYING WS-SHOW-IDX FROM 1 BY 1
        UNTIL WS-SHOW-IDX > WS-SHOW-CNT
        MOVE SPACES TO SHOWS-RECORD
        STRING FUNCTION TRIM(WS-SHOW-NAME(WS-SHOW-IDX) TRAILING)
               DELIMITED SIZE
               "|" DELIMITED SIZE
               FUNCTION TRIM(WS-SHOW-URL(WS-SHOW-IDX) TRAILING)
               DELIMITED SIZE
               INTO SHOWS-RECORD
        WRITE SHOWS-RECORD
    END-PERFORM
    CLOSE SHOWS-FILE.

SHOW-PODCAST-BROWSER.
    DISPLAY ANSI-CLEAR
    PERFORM RENDER-IDENT-TOP
    DISPLAY " "
    DISPLAY C-DIM "   " C-PURPLE "PROCEDURE DIVISION" C-DIM "."
            C-MUTED "  PODCAST-BROWSER" ANSI-RESET
    DISPLAY C-DIM "   ────────────────────────────────────────────────────────────────────────────"
            ANSI-RESET
    DISPLAY " "
    PERFORM VARYING WS-SHOW-IDX FROM 1 BY 1
        UNTIL WS-SHOW-IDX > WS-SHOW-CNT
        MOVE WS-SHOW-NAME(WS-SHOW-IDX) TO WS-FMT-IN
        MOVE 30 TO WS-FMT-WANT
        PERFORM FORMAT-CELL
        DISPLAY "   " C-DIM "[ " C-PINK WS-SHOW-IDX C-DIM " ]"
                "   " C-AMBER X"22"
                FUNCTION TRIM(WS-FMT-OUT(1:WS-FMT-OPOS) TRAILING)
                X"22" ANSI-RESET
    END-PERFORM
    DISPLAY " "
    DISPLAY C-DIM "   ────────────────────────────────────────────────────────────────────────────"
            ANSI-RESET
    DISPLAY " "
    DISPLAY "   " C-DIM "*>  " C-MUTED "Enter show #   "
            C-CYAN "A" C-MUTED " = add   "
            C-CYAN "D" C-MUTED " = delete   "
            C-CYAN "Q" C-MUTED " = quit" ANSI-RESET
    DISPLAY "   " C-MUTED " msg: " C-AMBER WS-MSG ANSI-RESET
    MOVE SPACES TO WS-MSG
    DISPLAY ANSI-SHOW-CUR
    DISPLAY "   " C-CYAN "cobol> " ANSI-RESET WITH NO ADVANCING.

HANDLE-PODCAST-INPUT.
    ACCEPT WS-SHOW-SEL
    DISPLAY ANSI-HIDE-CUR
    EVALUATE TRUE
        WHEN WS-DEL-STATE = 1
            PERFORM DELETE-PICK-NUMBER
        WHEN WS-DEL-STATE = 2
            PERFORM DELETE-CONFIRM
        WHEN WS-SHOW-SEL(1:1) = "Q" OR WS-SHOW-SEL(1:1) = "q"
            MOVE "N" TO WS-CONTINUE
        WHEN WS-SHOW-SEL(1:1) = "A" OR WS-SHOW-SEL(1:1) = "a"
            PERFORM ADD-PODCAST
        WHEN WS-SHOW-SEL(1:1) = "D" OR WS-SHOW-SEL(1:1) = "d"
            MOVE 1 TO WS-DEL-STATE
            MOVE "Enter the show # to delete." TO WS-MSG
        WHEN WS-SHOW-SEL(1:1) >= "0" AND WS-SHOW-SEL(1:1) <= "9"
            MOVE FUNCTION NUMVAL(WS-SHOW-SEL) TO WS-SHOW-NUM
            IF WS-SHOW-NUM >= 1 AND WS-SHOW-NUM <= WS-SHOW-CNT
                MOVE WS-SHOW-URL(WS-SHOW-NUM) TO WS-RSS-URL
                PERFORM BROWSE-EPISODES
            ELSE
                MOVE "Invalid show number." TO WS-MSG
            END-IF
        WHEN OTHER
            MOVE "Unknown command." TO WS-MSG
    END-EVALUATE.

DELETE-PICK-NUMBER.
    IF WS-SHOW-SEL(1:1) >= "0" AND WS-SHOW-SEL(1:1) <= "9"
        MOVE FUNCTION NUMVAL(WS-SHOW-SEL) TO WS-SHOW-NUM
        IF WS-SHOW-NUM >= 1 AND WS-SHOW-NUM <= WS-SHOW-CNT
            MOVE WS-SHOW-NUM TO WS-DEL-IDX
            MOVE 2 TO WS-DEL-STATE
            MOVE SPACES TO WS-MSG
            STRING "Delete '"
                   FUNCTION TRIM(WS-SHOW-NAME(WS-DEL-IDX) TRAILING)
                   "'?  Press D again to confirm."
                   DELIMITED SIZE INTO WS-MSG
        ELSE
            MOVE 0 TO WS-DEL-STATE
            MOVE "Invalid show number. Delete cancelled." TO WS-MSG
        END-IF
    ELSE
        MOVE 0 TO WS-DEL-STATE
        MOVE "Delete cancelled." TO WS-MSG
    END-IF.

DELETE-CONFIRM.
    IF WS-SHOW-SEL(1:1) = "D" OR WS-SHOW-SEL(1:1) = "d"
        PERFORM REMOVE-SHOW
        PERFORM SAVE-SHOWS
        MOVE 0 TO WS-DEL-STATE
        MOVE "Show deleted." TO WS-MSG
    ELSE
        MOVE 0 TO WS-DEL-STATE
        MOVE "Delete cancelled." TO WS-MSG
    END-IF.

REMOVE-SHOW.
    PERFORM VARYING WS-SHOW-IDX FROM WS-DEL-IDX BY 1
        UNTIL WS-SHOW-IDX >= WS-SHOW-CNT
        MOVE WS-SHOW-NAME(WS-SHOW-IDX + 1)
            TO WS-SHOW-NAME(WS-SHOW-IDX)
        MOVE WS-SHOW-URL(WS-SHOW-IDX + 1)
            TO WS-SHOW-URL(WS-SHOW-IDX)
    END-PERFORM
    SUBTRACT 1 FROM WS-SHOW-CNT.

ADD-PODCAST.
    IF WS-SHOW-CNT >= WS-MAX-SHOW
        MOVE "Show list is full." TO WS-MSG
        EXIT PARAGRAPH
    END-IF
    DISPLAY " "
    DISPLAY "   " C-CYAN "Enter RSS URL: " ANSI-RESET ANSI-SHOW-CUR
            WITH NO ADVANCING
    MOVE SPACES TO WS-NEW-URL
    ACCEPT WS-NEW-URL
    DISPLAY ANSI-HIDE-CUR
    IF FUNCTION TRIM(WS-NEW-URL) = SPACES
        MOVE "URL cannot be empty." TO WS-MSG
        EXIT PARAGRAPH
    END-IF
    IF WS-NEW-URL(1:7) NOT = "http://"
   AND WS-NEW-URL(1:8) NOT = "https://"
        MOVE "Invalid URL (must start with http:// or https://)."
            TO WS-MSG
        EXIT PARAGRAPH
    END-IF
    MOVE WS-NEW-URL TO WS-RSS-URL
    PERFORM FETCH-RSS-FEED
    PERFORM VALIDATE-FEED
    IF WS-VALIDATE-OK = "N"
        MOVE "Could not load a valid RSS feed from that URL." TO WS-MSG
        EXIT PARAGRAPH
    END-IF
    PERFORM EXTRACT-CHANNEL-TITLE
    ADD 1 TO WS-SHOW-CNT
    MOVE WS-CURR-TTL TO WS-SHOW-NAME(WS-SHOW-CNT)
    MOVE WS-NEW-URL  TO WS-SHOW-URL(WS-SHOW-CNT)
    PERFORM SAVE-SHOWS
    MOVE "Show added." TO WS-MSG.

*>  Confirm feed.rss looks like a podcast feed (cheap content sniff).
VALIDATE-FEED.
    MOVE "N" TO WS-VALIDATE-OK
    MOVE "N" TO WS-EOF
    OPEN INPUT RSS-FILE
    PERFORM UNTIL WS-EOF = "Y" OR WS-VALIDATE-OK = "Y"
        READ RSS-FILE INTO WS-LINE
            AT END MOVE "Y" TO WS-EOF
            NOT AT END
*>              Require podcast-specific markup. Do NOT accept a bare
*>              <title> — any HTML page has one (e.g. example.com).
                MOVE 0 TO WS-SCAN-POS
                INSPECT WS-LINE TALLYING WS-SCAN-POS FOR ALL "<rss"
                IF WS-SCAN-POS = 0
                    INSPECT WS-LINE TALLYING WS-SCAN-POS FOR ALL "<item"
                END-IF
                IF WS-SCAN-POS = 0
                    INSPECT WS-LINE TALLYING WS-SCAN-POS
                        FOR ALL "<channel"
                END-IF
                IF WS-SCAN-POS > 0
                    MOVE "Y" TO WS-VALIDATE-OK
                END-IF
        END-READ
    END-PERFORM
    CLOSE RSS-FILE.

*>  Pull the channel <title> (first <title> before the first <item>).
EXTRACT-CHANNEL-TITLE.
    MOVE SPACES TO WS-CURR-TTL
    MOVE "N" TO WS-EOF
    OPEN INPUT RSS-FILE
    PERFORM UNTIL WS-EOF = "Y" OR WS-CURR-TTL NOT = SPACES
        READ RSS-FILE INTO WS-LINE
            AT END MOVE "Y" TO WS-EOF
            NOT AT END
                MOVE SPACES TO WS-PART-A WS-PART-B
                UNSTRING WS-LINE DELIMITED BY "<item>"
                    INTO WS-PART-A WS-PART-B
                IF WS-PART-B NOT = SPACES
                    MOVE "Y" TO WS-EOF
                ELSE
                    PERFORM EXTRACT-TITLE
                END-IF
        END-READ
    END-PERFORM
    CLOSE RSS-FILE
    IF WS-CURR-TTL = SPACES
        MOVE WS-NEW-URL TO WS-CURR-TTL
    END-IF.

BROWSE-EPISODES.
    DISPLAY ANSI-CLEAR
    DISPLAY " "
    DISPLAY "  " C-CYAN ">>> " C-TEXT "Loading episodes..." ANSI-RESET
    PERFORM FETCH-RSS-FEED
    PERFORM PARSE-RSS-FEED
    IF WS-EP-CNT = 0
        PERFORM LOAD-MOCK-DATA
    ELSE
        MOVE "Y" TO WS-FETCH-OK
    END-IF
    MOVE 1 TO WS-PAGE-NUM
    MOVE "Y" TO WS-EP-CONTINUE
    PERFORM UNTIL WS-EP-CONTINUE = "N"
        PERFORM SHOW-BROWSER
        PERFORM HANDLE-BROWSER-INPUT
    END-PERFORM.

*>================================================================
*>   EPISODE BROWSER (select mode)
*>================================================================

SHOW-BROWSER.
    PERFORM CALC-PAGE-BOUNDS
    DISPLAY ANSI-CLEAR
    PERFORM RENDER-IDENT-TOP
    DISPLAY " "
    DISPLAY C-DIM "   " C-PURPLE "PROCEDURE DIVISION" C-DIM "."
            C-MUTED "  EPISODE-BROWSER" ANSI-RESET
    DISPLAY C-DIM "   ────────────────────────────────────────────────────────────────────────────"
            ANSI-RESET
    DISPLAY " "
    MOVE 0 TO WS-IDX-2D
    PERFORM VARYING WS-DISP-IDX FROM WS-PAGE-START BY 1
        UNTIL WS-DISP-IDX > WS-PAGE-END
        ADD 1 TO WS-IDX-2D
        PERFORM FORMAT-BROWSER-DATE
        MOVE WS-EP-TITLE(WS-DISP-IDX)(1:40) TO WS-TITLE-50
        DISPLAY "   " C-DIM "[ " C-PINK WS-IDX-2D C-DIM " ]"
                "   " C-PINK WS-EP-NUM(WS-DISP-IDX)
                "   " C-AMBER X"22"
                FUNCTION TRIM(WS-TITLE-50 TRAILING)
                X"22" ANSI-COL-DATE C-MUTED WS-DATE-16
                ANSI-RESET
    END-PERFORM
    DISPLAY " "
    DISPLAY C-DIM "   ────────────────────────────────────────────────────────────────────────────"
            ANSI-RESET
    IF WS-STATUS NOT = SPACES
        DISPLAY "   " C-AMBER ">> " WS-STATUS ANSI-RESET
        MOVE SPACES TO WS-STATUS
    END-IF
    DISPLAY " "
    DISPLAY "   " C-DIM "*>  " C-MUTED "Enter episode # (1-" WS-PAGE-ITEMS
            ")  " C-CYAN "S" C-MUTED " = shows  "
            C-CYAN "P" C-MUTED " = PREV PAGE  "
            C-CYAN "N" C-MUTED " = NEXT PAGE" ANSI-RESET
    DISPLAY "   " C-MUTED " msg: " C-AMBER WS-MSG ANSI-RESET
    MOVE SPACES TO WS-MSG
    DISPLAY ANSI-SHOW-CUR
    DISPLAY "   " C-CYAN "cobol> " ANSI-RESET WITH NO ADVANCING.

FORMAT-BROWSER-DATE.
    IF WS-EP-DATE(WS-DISP-IDX)(7:1) = " "
        STRING WS-EP-DATE(WS-DISP-IDX)(1:5) DELIMITED SIZE
               "0"                           DELIMITED SIZE
               WS-EP-DATE(WS-DISP-IDX)(6:1) DELIMITED SIZE
               " "                           DELIMITED SIZE
               WS-EP-DATE(WS-DISP-IDX)(8:8) DELIMITED SIZE
               INTO WS-DATE-16
    ELSE
        MOVE WS-EP-DATE(WS-DISP-IDX)(1:16) TO WS-DATE-16
    END-IF.

HANDLE-BROWSER-INPUT.
    ACCEPT WS-SELECTION
    DISPLAY ANSI-HIDE-CUR
    EVALUATE TRUE
        WHEN WS-SELECTION(1:1) = "S" OR WS-SELECTION(1:1) = "s"
            MOVE "N" TO WS-EP-CONTINUE
        WHEN WS-SELECTION(1:1) = "P" OR WS-SELECTION(1:1) = "p"
            PERFORM PREV-PAGE
        WHEN WS-SELECTION(1:1) = "N" OR WS-SELECTION(1:1) = "n"
            PERFORM NEXT-PAGE
        WHEN WS-SELECTION(1:1) >= "0" AND WS-SELECTION(1:1) <= "9"
            MOVE FUNCTION NUMVAL(WS-SELECTION) TO WS-SEL-NUM
            IF WS-SEL-NUM >= 1 AND WS-SEL-NUM <= WS-PAGE-ITEMS
                COMPUTE WS-PLAYING = WS-PAGE-START + WS-SEL-NUM - 1
                PERFORM SELECT-EPISODE
            ELSE
                MOVE "Invalid episode number. Try again." TO WS-STATUS
            END-IF
        WHEN OTHER
            MOVE "Unknown command." TO WS-STATUS
    END-EVALUATE.

CALC-PAGE-BOUNDS.
    COMPUTE WS-PAGE-START = (WS-PAGE-NUM - 1) * WS-PAGE-SIZE + 1
    COMPUTE WS-PAGE-END   = WS-PAGE-NUM * WS-PAGE-SIZE
    IF WS-PAGE-END > WS-EP-CNT
        MOVE WS-EP-CNT TO WS-PAGE-END
    END-IF
    COMPUTE WS-PAGE-ITEMS = WS-PAGE-END - WS-PAGE-START + 1.

PREV-PAGE.
    IF WS-PAGE-NUM > 1
        SUBTRACT 1 FROM WS-PAGE-NUM
    ELSE
        MOVE "FIRST PAGE" TO WS-MSG
    END-IF.

NEXT-PAGE.
    IF WS-PAGE-NUM * WS-PAGE-SIZE < WS-EP-CNT
        ADD 1 TO WS-PAGE-NUM
    ELSE
        MOVE "LAST PAGE" TO WS-MSG
    END-IF.

SELECT-EPISODE.
    MOVE "N" TO WS-PAUSED
    MOVE 0 TO WS-TOTAL-PAUSED
    MOVE 0 TO WS-SEEK-BASE
    MOVE WS-EP-DURSEC(WS-PLAYING) TO WS-DURATION-SEC
    IF WS-DURATION-SEC = 0
        MOVE 3520 TO WS-DURATION-SEC
    END-IF
    PERFORM EXTRACT-CHAPTERS
    MOVE "Y" TO WS-STOP-FLAG
    ACCEPT WS-START-TIME FROM TIME
    MOVE "N" TO WS-STOP-FLAG
    MOVE 1 TO WS-ACTIVE-CHAP
    PERFORM START-PLAYBACK
    ACCEPT WS-START-TIME FROM TIME
    PERFORM PLAY-LOOP
    PERFORM STOP-PLAYBACK.

*>================================================================
*>   PLAYBACK
*>================================================================

START-PLAYBACK.
    IF WS-EP-URL(WS-PLAYING) NOT = SPACES
        MOVE SPACES TO WS-CMD
        MOVE WS-SEEK-BASE TO WS-SEEK-DISP
        IF WS-OS = "Unix"
            STRING "setsid ffplay -nodisp -autoexit -loglevel quiet"
                DELIMITED SIZE
                " -ss " FUNCTION TRIM(WS-SEEK-DISP) " "
                DELIMITED SIZE
                X"22" FUNCTION TRIM(WS-EP-URL(WS-PLAYING) TRAILING) X"22"
                DELIMITED SIZE
                " </dev/null >/dev/null 2>&1 &"
                DELIMITED SIZE
                INTO WS-CMD
        ELSE
            STRING "ffplay -nodisp -autoexit -loglevel quiet"
                DELIMITED SIZE
                " -ss " FUNCTION TRIM(WS-SEEK-DISP) " "
                DELIMITED SIZE
                X"22" FUNCTION TRIM(WS-EP-URL(WS-PLAYING) TRAILING) X"22"
                DELIMITED SIZE
                FUNCTION TRIM(WS-BG-SFX TRAILING)
                DELIMITED SIZE
                INTO WS-CMD
        END-IF
        CALL "SYSTEM" USING WS-CMD
    END-IF.

PLAY-LOOP.
    PERFORM UNTIL WS-ELAPSED-SEC >= WS-DURATION-SEC
        OR WS-STOP-FLAG = "Y"
        ACCEPT WS-CURR-TIME FROM TIME
        PERFORM CALC-ELAPSED
        PERFORM FIND-ACTIVE-CHAPTER
        PERFORM UPDATE-MOCK-STATS
        PERFORM SHOW-PLAY-UI
        PERFORM READ-KEY-WITH-SLEEP
    END-PERFORM.

CALC-ELAPSED.
    IF WS-PAUSED = "Y"
        EXIT PARAGRAPH
    END-IF
    COMPUTE WS-ELAPSED-SEC = WS-SEEK-BASE +
        (WS-CT-HH * 3600 + WS-CT-MM * 60 + WS-CT-SS) -
        (WS-ST-HH * 3600 + WS-ST-MM * 60 + WS-ST-SS) -
        WS-TOTAL-PAUSED
    IF WS-ELAPSED-SEC < 0
        ADD 86400 TO WS-ELAPSED-SEC
    END-IF
    IF WS-ELAPSED-SEC > WS-DURATION-SEC
        MOVE WS-DURATION-SEC TO WS-ELAPSED-SEC
    END-IF.

FIND-ACTIVE-CHAPTER.
    PERFORM VARYING WS-WAVE-IDX FROM WS-CH-CNT BY -1
        UNTIL WS-WAVE-IDX = 0
        IF WS-ELAPSED-SEC >= WS-CH-SEC(WS-WAVE-IDX)
            MOVE WS-WAVE-IDX TO WS-ACTIVE-CHAP
            EXIT PERFORM
        END-IF
    END-PERFORM.

UPDATE-MOCK-STATS.
    COMPUTE WS-CPU-A = (WS-ELAPSED-SEC * 3) / WS-DURATION-SEC + 1
    COMPUTE WS-CPU-B = WS-CPU-A * 3 - 2
    IF WS-CPU-B > 9 MOVE 8 TO WS-CPU-B END-IF
    COMPUTE WS-NET = 35 + (WS-ELAPSED-SEC * 15) / WS-DURATION-SEC.

STOP-PLAYBACK.
    MOVE "Y" TO WS-STOP-FLAG
    CALL "SYSTEM" USING WS-KILL-CMD
    MOVE "rm -f /tmp/cobkey.txt 2>/dev/null" TO WS-CMD
    CALL "SYSTEM" USING WS-CMD
    MOVE "N" TO WS-UI-DRAWN
    MOVE 0 TO WS-ELAPSED-SEC WS-PLAYING
    MOVE SPACES TO WS-STATUS
    MOVE "Playback stopped. Returned to browser." TO WS-STATUS.

READ-KEY-WITH-SLEEP.
    CALL "SYSTEM" USING WS-KEY-CMD
    MOVE "0" TO WS-KEY-INPUT
    OPEN INPUT KEY-FILE
    IF WS-KEY-STATUS = "00"
        READ KEY-FILE INTO WS-KEY-INPUT
            AT END CONTINUE
        END-READ
        CLOSE KEY-FILE
    END-IF
    EVALUATE WS-KEY-INPUT
        WHEN "1"
            MOVE "Y" TO WS-STOP-FLAG
        WHEN "3"
            IF WS-PAUSED = "N"
                IF WS-PAUSE-CMD NOT = SPACES
                    CALL "SYSTEM" USING WS-PAUSE-CMD
                END-IF
                ACCEPT WS-PAUSE-TIME FROM TIME
                MOVE "Y" TO WS-PAUSED
            ELSE
                IF WS-RESUME-CMD NOT = SPACES
                    CALL "SYSTEM" USING WS-RESUME-CMD
                END-IF
                ACCEPT WS-CURR-TIME FROM TIME
                COMPUTE WS-EL-TEMP =
                    (WS-CT-HH * 3600 + WS-CT-MM * 60 + WS-CT-SS) -
                    (WS-PT-HH * 3600 + WS-PT-MM * 60 + WS-PT-SS)
                IF WS-EL-TEMP < 0
                    ADD 86400 TO WS-EL-TEMP
                END-IF
                ADD WS-EL-TEMP TO WS-TOTAL-PAUSED
                MOVE "N" TO WS-PAUSED
            END-IF
        WHEN "4"
*>          Forward 30s (clamped to the episode duration)
            COMPUTE WS-SEEK-POS = WS-ELAPSED-SEC + 30
            IF WS-SEEK-POS > WS-DURATION-SEC
                MOVE WS-DURATION-SEC TO WS-SEEK-POS
            END-IF
            PERFORM DO-SEEK
        WHEN "5"
*>          Back 30s (clamped to the start)
            IF WS-ELAPSED-SEC > 30
                COMPUTE WS-SEEK-POS = WS-ELAPSED-SEC - 30
            ELSE
                MOVE 0 TO WS-SEEK-POS
            END-IF
            PERFORM DO-SEEK
        WHEN OTHER
            CONTINUE
    END-EVALUATE.

DO-SEEK.
*>  Restart ffplay at WS-SEEK-POS and re-sync the wall-clock so the
*>  displayed time, chapter and progress bar follow the new position.
    CALL "SYSTEM" USING WS-KILL-CMD
    MOVE WS-SEEK-POS TO WS-SEEK-BASE
    MOVE 0 TO WS-TOTAL-PAUSED
    MOVE "N" TO WS-PAUSED
    PERFORM START-PLAYBACK
    ACCEPT WS-START-TIME FROM TIME.

*>================================================================
*>   FULL IDE UI (play mode)
*>================================================================

SHOW-PLAY-UI.
    IF WS-UI-DRAWN = "N"
        DISPLAY ANSI-CLEAR
        MOVE "Y" TO WS-UI-DRAWN
    ELSE
        DISPLAY ANSI-HOME
    END-IF
    PERFORM RENDER-IDENT-TOP
    PERFORM COMPUTE-PLAY-TIMES
    PERFORM RENDER-DATA-DIV
    PERFORM RENDER-PROCEDURE-DIV
    PERFORM RENDER-BOTTOM-ROW
    PERFORM RENDER-STATUS-PROMPT
    DISPLAY ANSI-CLR-EOS.

COMPUTE-PLAY-TIMES.
    COMPUTE WS-DUR-HH  = WS-DURATION-SEC / 3600
    COMPUTE WS-EL-TEMP = WS-DURATION-SEC - WS-DUR-HH * 3600
    COMPUTE WS-DUR-MM  = WS-EL-TEMP / 60
    COMPUTE WS-DUR-SS  = WS-EL-TEMP - WS-DUR-MM * 60
    COMPUTE WS-EL-HH   = WS-ELAPSED-SEC / 3600
    COMPUTE WS-EL-TEMP = WS-ELAPSED-SEC - WS-EL-HH * 3600
    COMPUTE WS-EL-MM   = WS-EL-TEMP / 60
    COMPUTE WS-EL-SS   = WS-EL-TEMP - WS-EL-MM * 60
    IF WS-DURATION-SEC > 0
        COMPUTE WS-BAR-FILLED =
            (WS-ELAPSED-SEC * WS-BAR-WIDTH) / WS-DURATION-SEC
    ELSE
        MOVE 0 TO WS-BAR-FILLED
    END-IF
    COMPUTE WS-BAR-EMPTY = WS-BAR-WIDTH - WS-BAR-FILLED.

*>────────────────────────────────────────────────────────────────
RENDER-IDENT-TOP.
*>────────────────────────────────────────────────────────────────
    DISPLAY " "
    DISPLAY "      " C-PURPLE "IDENTIFICATION DIVISION." ANSI-RESET
    DISPLAY "      " C-PURPLE "PROGRAM-ID."
            C-CYAN "   COBPLAYR." ANSI-RESET
    DISPLAY "      " C-PURPLE "AUTHOR."
            C-CYAN "       ANONYMOUS." ANSI-RESET
    DISPLAY "      " C-PURPLE "DATE-COMPILED."
            C-CYAN WS-DATE-DISP "." ANSI-RESET
    DISPLAY " ".

*>────────────────────────────────────────────────────────────────
RENDER-DATA-DIV.
*>────────────────────────────────────────────────────────────────
    DISPLAY C-DIM "   ┌─ " C-PURPLE "DATA DIVISION" C-DIM " "
            C-MUTED "WORKING-STORAGE" C-DIM " · "
            C-MUTED "NOW-PLAYING"
            C-DIM ANSI-CLR-LINE ANSI-COL-87 "─┐"
            ANSI-RESET
    DISPLAY C-DIM "   │" ANSI-CLR-LINE ANSI-COL-88 "│" ANSI-RESET

    DISPLAY C-DIM "   │  " C-PINK "01" C-DIM "  "
            C-TEXT "SHOW-NAME   " C-PURPLE " VALUE   "
            C-AMBER X"22" "Area de Transferencia" X"22"
            C-MUTED ANSI-COL-PIC "PIC " C-PINK "X(32)"
            C-DIM "  │" ANSI-RESET

    MOVE WS-EP-TITLE(WS-PLAYING) TO WS-FMT-IN
    MOVE 42 TO WS-FMT-WANT
    PERFORM FORMAT-CELL
    DISPLAY C-DIM "   │  " C-PINK "01" C-DIM "  "
            C-TEXT "EP-TITLE    " C-PURPLE " VALUE   "
            C-AMBER X"22"
            FUNCTION TRIM(WS-FMT-OUT(1:WS-FMT-OPOS) TRAILING)
            X"22"
            C-MUTED ANSI-COL-PIC "PIC " C-PINK "X(72)"
            C-DIM "  │" ANSI-RESET

    DISPLAY C-DIM "   │  " C-PINK "01" C-DIM "  "
            C-TEXT "EP-NUMBER   " C-PURPLE " VALUE   "
            C-PINK WS-EP-NUM(WS-PLAYING)
            C-MUTED ANSI-COL-PIC "PIC " C-PINK "9(03)"
            C-DIM "  │" ANSI-RESET

    MOVE FUNCTION TRIM(WS-EP-DATE(WS-PLAYING)(1:16) TRAILING)
        TO WS-DATE-16
    DISPLAY C-DIM "   │  " C-PINK "01" C-DIM "  "
            C-TEXT "PUB-DATE    " C-PURPLE " VALUE   "
            C-AMBER X"22" WS-DATE-16 X"22"
            C-MUTED ANSI-COL-PIC "PIC " C-PINK "X(10)"
            C-DIM "  │" ANSI-RESET

    DISPLAY C-DIM "   │  " C-PINK "01" C-DIM "  "
            C-TEXT "DURATION-SEC" C-PURPLE " VALUE   "
            C-PINK WS-EP-DURSEC(WS-PLAYING)
            C-DIM "  *  "
            C-CYAN WS-DUR-HH ":" WS-DUR-MM ":" WS-DUR-SS
            C-MUTED ANSI-COL-PIC "PIC " C-PINK "9(05)"
            C-DIM "  │" ANSI-RESET
    DISPLAY C-DIM "   │" ANSI-CLR-LINE ANSI-COL-88 "│" ANSI-RESET.

*>────────────────────────────────────────────────────────────────
RENDER-PROCEDURE-DIV.
*>────────────────────────────────────────────────────────────────
    DISPLAY C-DIM "   ├─ " C-PURPLE "PROCEDURE DIVISION" C-DIM " "
            C-CYAN "PLAY-EPISODE"
            C-DIM ANSI-CLR-LINE ANSI-COL-87 "─┤"
            ANSI-RESET
    DISPLAY C-DIM "   │" ANSI-CLR-LINE ANSI-COL-88 "│" ANSI-RESET
*>  Centered in the 83-col interior: "MOVE ... ." is 50 cols → pad 16
    DISPLAY C-DIM "   │" WS-PAD(1:16) C-PURPLE "MOVE   " C-CYAN
            WS-EL-HH ":" WS-EL-MM ":" WS-EL-SS
            C-PURPLE "  TO  " C-TEXT "POSITION-SEC"
            C-PURPLE "  OF  " C-PINK WS-DUR-HH ":" WS-DUR-MM ":" WS-DUR-SS
            C-DIM "  ." ANSI-CLR-LINE ANSI-COL-88 C-DIM "│" ANSI-RESET
    DISPLAY C-DIM "   │" ANSI-CLR-LINE ANSI-COL-88 "│" ANSI-RESET
    MOVE SPACES TO WS-BAR-LINE
    PERFORM VARYING WS-BAR-IDX FROM 1 BY 1
        UNTIL WS-BAR-IDX > WS-BAR-FILLED
        MOVE "|" TO WS-BAR-LINE(WS-BAR-IDX:1)
    END-PERFORM
    PERFORM VARYING WS-BAR-IDX FROM 1 BY 1
        UNTIL WS-BAR-IDX > WS-BAR-EMPTY
        COMPUTE WS-DASH-IDX = WS-BAR-FILLED + WS-BAR-IDX
        MOVE "." TO WS-BAR-LINE(WS-DASH-IDX:1)
    END-PERFORM
*>  Centered: "[" + 65-col bar + "]" = 67 cols → pad 8
*>  Colourful bar: muted brackets, green filled, dim empty.
    DISPLAY C-DIM "   │" WS-PAD(1:8) C-MUTED "["
            ANSI-RESET WITH NO ADVANCING
    IF WS-BAR-FILLED > 0
        DISPLAY C-GREEN WS-BAR-LINE(1:WS-BAR-FILLED)
                ANSI-RESET WITH NO ADVANCING
    END-IF
    IF WS-BAR-EMPTY > 0
        DISPLAY C-DIM WS-BAR-LINE(WS-BAR-FILLED + 1:WS-BAR-EMPTY)
                ANSI-RESET WITH NO ADVANCING
    END-IF
    DISPLAY C-MUTED "]"
            ANSI-CLR-LINE ANSI-COL-88 C-DIM "│" ANSI-RESET
    DISPLAY C-DIM "   │" ANSI-CLR-LINE ANSI-COL-88 "│" ANSI-RESET
*>  Centered: fixed parts = 46 cols + chapter-title display width
    MOVE WS-CH-TITLE(WS-ACTIVE-CHAP) TO WS-FMT-IN
    PERFORM MEASURE-WIDTH
    COMPUTE WS-CENTER-PAD = (83 - (46 + WS-FMT-COLS)) / 2
    IF WS-CENTER-PAD < 1 MOVE 1 TO WS-CENTER-PAD END-IF
    DISPLAY C-DIM "   │" WS-PAD(1:WS-CENTER-PAD)
            C-PURPLE "IF  " C-TEXT "CURRENT-CHAPTER"
            C-DIM "  =  " C-AMBER X"22"
            FUNCTION TRIM(WS-CH-TITLE(WS-ACTIVE-CHAP) TRAILING)(1:30)
            X"22"
            C-MUTED "   *  started  " C-PINK WS-CH-TS(WS-ACTIVE-CHAP)
            ANSI-CLR-LINE ANSI-COL-88 C-DIM "│" ANSI-RESET
    DISPLAY C-DIM "   │" ANSI-CLR-LINE ANSI-COL-88 "│" ANSI-RESET.

*>────────────────────────────────────────────────────────────────
RENDER-BOTTOM-ROW.
*>────────────────────────────────────────────────────────────────
    DISPLAY C-DIM "   ├────────────────────────────────────────────────"
            "┬──────────────────────────────────┤" ANSI-RESET
    DISPLAY C-DIM "   │ " C-PURPLE "LINKAGE SECTION"
            C-DIM "   " C-MUTED "QUEUE"
            C-DIM "                        │ " C-PURPLE "FILE SECTION"
            C-DIM "                     │" ANSI-RESET
    DISPLAY C-DIM "   │  " C-MUTED "88-LEVEL UP-NEXT"
            C-DIM "                              │  " C-MUTED "CHAPTER-MAP"
            C-DIM "                     │" ANSI-RESET
    DISPLAY C-DIM "   │                                                "
            "│                                  │" ANSI-RESET

*>  Sliding window over the chapter list so the active chapter stays
*>  visible: show 4 rows starting one before the active chapter,
*>  clamped to the available range.
    IF WS-CH-CNT <= 4
        MOVE 1 TO WS-CH-START
    ELSE
        COMPUTE WS-CH-START = WS-ACTIVE-CHAP - 1
        IF WS-CH-START < 1
            MOVE 1 TO WS-CH-START
        END-IF
        IF WS-CH-START > WS-CH-CNT - 3
            COMPUTE WS-CH-START = WS-CH-CNT - 3
        END-IF
    END-IF

    PERFORM VARYING WS-DISP-IDX FROM 1 BY 1 UNTIL WS-DISP-IDX > 4
        PERFORM RENDER-QUEUE-AND-CHAPTER-ROW
    END-PERFORM
    DISPLAY C-DIM "   └────────────────────────────────────────────────"
            "┴──────────────────────────────────┘" ANSI-RESET.

RENDER-QUEUE-AND-CHAPTER-ROW.
    COMPUTE WS-IDX-2D = WS-PLAYING + WS-DISP-IDX
    IF WS-IDX-2D > WS-EP-CNT MOVE WS-EP-CNT TO WS-IDX-2D END-IF
    MOVE WS-EP-TITLE(WS-IDX-2D) TO WS-FMT-IN
    MOVE 18 TO WS-FMT-WANT
    PERFORM FORMAT-CELL

    DISPLAY C-DIM "   │  " C-PINK "88" C-DIM "  "
            C-TEXT "EP-" WS-EP-NUM(WS-IDX-2D) " "
            C-PURPLE "VALUE " C-AMBER X"22"
            WS-FMT-OUT(1:WS-FMT-OPOS) X"22"
            "        "
            ANSI-RESET WITH NO ADVANCING

    COMPUTE WS-CH-IDX = WS-CH-START + WS-DISP-IDX - 1
    IF WS-CH-IDX <= WS-CH-CNT
        MOVE WS-CH-TITLE(WS-CH-IDX) TO WS-FMT-IN
        MOVE 16 TO WS-FMT-WANT
        PERFORM FORMAT-CELL
        IF WS-CH-IDX = WS-ACTIVE-CHAP
*>          Highlight only the cell interior — not the │ delimiters:
*>          BG-ACT starts after the left │ and is reset before the right │
            DISPLAY C-DIM " │" BG-ACT "  " C-CYAN "►  "
                    C-PINK WS-CH-TS(WS-CH-IDX) "  "
                    C-AMBER X"22" WS-FMT-OUT(1:WS-FMT-OPOS) X"22"
                    "    " ANSI-RESET C-DIM "│" ANSI-RESET
        ELSE
            DISPLAY C-DIM " │     "
                    C-PINK WS-CH-TS(WS-CH-IDX) "  "
                    C-AMBER X"22" WS-FMT-OUT(1:WS-FMT-OPOS) X"22"
                    "    " C-DIM "│" ANSI-RESET
        END-IF
    ELSE
        DISPLAY C-DIM " │                                  │" ANSI-RESET
    END-IF.

*>────────────────────────────────────────────────────────────────
*> FORMAT-CELL - pad/truncate WS-FMT-IN to WS-FMT-WANT DISPLAY
*> columns (not bytes), respecting UTF-8 multi-byte boundaries so
*> accented chars never get sliced (no � glyphs) and the right-hand
*> box borders stay aligned. Result in WS-FMT-OUT(1:WS-FMT-OPOS).
*>────────────────────────────────────────────────────────────────
FORMAT-CELL.
    MOVE SPACES TO WS-FMT-OUT
    MOVE 0 TO WS-FMT-COLS
    MOVE 0 TO WS-FMT-OPOS
    PERFORM VARYING WS-FMT-IPOS FROM 1 BY 1
        UNTIL WS-FMT-IPOS > LENGTH OF WS-FMT-IN
        MOVE WS-FMT-IN(WS-FMT-IPOS:1) TO WS-FMT-BYTE
        COMPUTE WS-FMT-ORD = FUNCTION ORD(WS-FMT-BYTE) - 1
        IF WS-FMT-ORD >= 128 AND WS-FMT-ORD <= 191
*>          UTF-8 continuation byte: part of the current column
            ADD 1 TO WS-FMT-OPOS
            MOVE WS-FMT-BYTE TO WS-FMT-OUT(WS-FMT-OPOS:1)
        ELSE
*>          ASCII / lead byte: begins a new display column. A 4-byte
*>          sequence (lead >= 240, code point >= U+10000) is an emoji
*>          that most terminals render two columns wide.
            IF WS-FMT-ORD >= 240
                MOVE 2 TO WS-FMT-CW
            ELSE
                MOVE 1 TO WS-FMT-CW
            END-IF
            IF WS-FMT-COLS + WS-FMT-CW > WS-FMT-WANT
                EXIT PERFORM
            END-IF
            ADD WS-FMT-CW TO WS-FMT-COLS
            ADD 1 TO WS-FMT-OPOS
            MOVE WS-FMT-BYTE TO WS-FMT-OUT(WS-FMT-OPOS:1)
        END-IF
    END-PERFORM
    PERFORM UNTIL WS-FMT-COLS >= WS-FMT-WANT
        ADD 1 TO WS-FMT-OPOS
        MOVE SPACE TO WS-FMT-OUT(WS-FMT-OPOS:1)
        ADD 1 TO WS-FMT-COLS
    END-PERFORM.

*>────────────────────────────────────────────────────────────────
*> MEASURE-WIDTH - count the DISPLAY-column width of WS-FMT-IN
*> (trimmed) into WS-FMT-COLS, counting each UTF-8 character once
*> regardless of how many bytes it occupies.
*>────────────────────────────────────────────────────────────────
MEASURE-WIDTH.
    COMPUTE WS-FMT-LEN =
        FUNCTION LENGTH(FUNCTION TRIM(WS-FMT-IN TRAILING))
    MOVE 0 TO WS-FMT-COLS
    PERFORM VARYING WS-FMT-IPOS FROM 1 BY 1
        UNTIL WS-FMT-IPOS > WS-FMT-LEN
        MOVE WS-FMT-IN(WS-FMT-IPOS:1) TO WS-FMT-BYTE
        COMPUTE WS-FMT-ORD = FUNCTION ORD(WS-FMT-BYTE) - 1
        IF WS-FMT-ORD < 128 OR WS-FMT-ORD > 191
            IF WS-FMT-ORD >= 240
                ADD 2 TO WS-FMT-COLS
            ELSE
                ADD 1 TO WS-FMT-COLS
            END-IF
        END-IF
    END-PERFORM.

*>────────────────────────────────────────────────────────────────
RENDER-STATUS-PROMPT.
*>────────────────────────────────────────────────────────────────
    DISPLAY " "
    IF WS-PAUSED = "Y"
        DISPLAY "   " C-DIM "● " C-PINK "PAUSED" C-DIM "   "
                C-MUTED "EP-" C-PINK WS-EP-NUM(WS-PLAYING)
                C-DIM "   ffplay -nodisp   "
                C-DIM "GnuCOBOL 3.1.2  podcast-player.cob:PROC-"
                WS-EP-NUM(WS-PLAYING) ANSI-RESET
    ELSE
        DISPLAY "   " C-DIM "● " C-CYAN "RUN" C-DIM "   "
                C-MUTED "EP-" C-PINK WS-EP-NUM(WS-PLAYING)
                C-DIM "   ffplay -nodisp   "
                C-DIM "GnuCOBOL 3.1.2  podcast-player.cob:PROC-"
                WS-EP-NUM(WS-PLAYING) ANSI-RESET
    END-IF
    DISPLAY C-DIM "   ─────────────────────────────────────────────────────────────────────────────"
            ANSI-RESET
    DISPLAY "   " C-DIM "*>  "
            C-CYAN "Q" C-MUTED " stop"
            "              "
            C-CYAN "P" C-MUTED " play/pause"
            "            "
            C-CYAN "F" C-MUTED " +30sec"
            "             "
            C-CYAN "B" C-MUTED " -30sec" ANSI-RESET.
*>  DEBUG line - uncomment for keypress diagnostics:
*>  DISPLAY "   " C-DIM "DEBUG  key-code=[" C-PINK WS-KEY-INPUT
*>          C-DIM "]  (0=none 1=Q 3=P)  paused=[" C-PINK WS-PAUSED
*>          C-DIM "]  elapsed=" C-PINK WS-ELAPSED-SEC ANSI-RESET.

*>================================================================
CLEANUP-AND-EXIT.
*>================================================================
    CALL "SYSTEM" USING WS-KILL-CMD.

*>================================================================
SHOW-GOODBYE.
*>================================================================
    DISPLAY ANSI-CLEAR
    DISPLAY " "
    DISPLAY "   " C-PURPLE "GOBACK" C-DIM "." ANSI-RESET
    DISPLAY "   " C-MUTED "STOP RUN" C-DIM "." ANSI-RESET
    DISPLAY " "
    DISPLAY "   " C-CYAN "Thanks for listening! Ate a proxima!" ANSI-RESET
    DISPLAY " ".
