#!/usr/bin/env bash
#==============================================================================
# test-unit.sh — Unit tests for podcast-player.cob business logic
#
# Tests pure computation paragraphs without launching the TUI.
# Each test compiles a tiny COBOL stub that exercises one paragraph,
# runs it, and checks the output.
#
# Usage:  bash test-unit.sh
# Needs:  cobc (GnuCOBOL 3.x)
#==============================================================================

PASS=0; FAIL=0
TMPDIR_T=$(mktemp -d)
trap 'rm -rf "$TMPDIR_T"' EXIT

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
DIM='\033[2m'; RESET='\033[0m'

header() { echo -e "\n${CYAN}── $1${RESET}"; }
ok()     { echo -e "  ${GREEN}✔  $1${RESET}"; ((PASS++)); }
fail()   { echo -e "  ${RED}✘  $1${RESET}"; ((FAIL++)); }

run_cobol() {
    # $1 = label  $2 = cobol source (heredoc string)  $3 = expected output
    local label="$1" src="$2" expected="$3"
    local srcf="$TMPDIR_T/test_$PASS$FAIL.cob"
    local bin="$TMPDIR_T/test_$PASS$FAIL"
    echo "$src" > "$srcf"
    if ! cobc -free -x "$srcf" -o "$bin" 2>"$TMPDIR_T/err.txt"; then
        fail "$label  [COMPILE ERROR]"
        cat "$TMPDIR_T/err.txt" | head -5
        return
    fi
    local got
    got=$("$bin" 2>/dev/null | tr -d '\r')
    if [[ "$got" == "$expected" ]]; then
        ok "$label"
    else
        fail "$label"
        echo -e "     expected: ${DIM}$expected${RESET}"
        echo -e "     got     : ${DIM}$got${RESET}"
    fi
}

#==============================================================================
header "PARSE-DURATION — HH:MM:SS → seconds"
#==============================================================================

run_cobol "01:55:48 → 6948 seconds" '
>>SOURCE FORMAT IS FREE
IDENTIFICATION DIVISION. PROGRAM-ID. T1.
DATA DIVISION. WORKING-STORAGE SECTION.
01 WS-DUR-HH  PIC 99 VALUE 0.
01 WS-DUR-MM  PIC 99 VALUE 0.
01 WS-DUR-SS  PIC 99 VALUE 0.
01 WS-RESULT  PIC 9(5) VALUE 0.
01 WS-PART-A  PIC X(20) VALUE "01".
01 WS-PART-B  PIC X(20) VALUE "55".
01 WS-PART-C  PIC X(20) VALUE "48".
PROCEDURE DIVISION.
    MOVE FUNCTION NUMVAL(WS-PART-A) TO WS-DUR-HH
    MOVE FUNCTION NUMVAL(WS-PART-B) TO WS-DUR-MM
    MOVE FUNCTION NUMVAL(WS-PART-C) TO WS-DUR-SS
    COMPUTE WS-RESULT = WS-DUR-HH * 3600 + WS-DUR-MM * 60 + WS-DUR-SS
    DISPLAY WS-RESULT
    STOP RUN.
' "06948"

run_cobol "00:58:40 → 3520 seconds" '
>>SOURCE FORMAT IS FREE
IDENTIFICATION DIVISION. PROGRAM-ID. T2.
DATA DIVISION. WORKING-STORAGE SECTION.
01 WS-DUR-HH  PIC 99 VALUE 0.
01 WS-DUR-MM  PIC 99 VALUE 0.
01 WS-DUR-SS  PIC 99 VALUE 0.
01 WS-RESULT  PIC 9(5) VALUE 0.
PROCEDURE DIVISION.
    MOVE 0  TO WS-DUR-HH
    MOVE 58 TO WS-DUR-MM
    MOVE 40 TO WS-DUR-SS
    COMPUTE WS-RESULT = WS-DUR-HH * 3600 + WS-DUR-MM * 60 + WS-DUR-SS
    DISPLAY WS-RESULT
    STOP RUN.
' "03520"

run_cobol "00:00:00 → 0 seconds (edge)" '
>>SOURCE FORMAT IS FREE
IDENTIFICATION DIVISION. PROGRAM-ID. T3.
DATA DIVISION. WORKING-STORAGE SECTION.
01 WS-RESULT PIC 9(5) VALUE 0.
PROCEDURE DIVISION.
    COMPUTE WS-RESULT = 0 * 3600 + 0 * 60 + 0
    DISPLAY WS-RESULT
    STOP RUN.
' "00000"

#==============================================================================
header "COMPUTE-PLAY-TIMES — elapsed seconds → HH:MM:SS display"
#==============================================================================

run_cobol "73 elapsed secs → 00:01:13" '
>>SOURCE FORMAT IS FREE
IDENTIFICATION DIVISION. PROGRAM-ID. T4.
DATA DIVISION. WORKING-STORAGE SECTION.
01 WS-ELAPSED-SEC  PIC 9(5) VALUE 73.
01 WS-EL-HH        PIC 99   VALUE 0.
01 WS-EL-MM        PIC 99   VALUE 0.
01 WS-EL-SS        PIC 99   VALUE 0.
01 WS-EL-TEMP      PIC 9(5) VALUE 0.
PROCEDURE DIVISION.
    COMPUTE WS-EL-HH   = WS-ELAPSED-SEC / 3600
    COMPUTE WS-EL-TEMP = WS-ELAPSED-SEC - WS-EL-HH * 3600
    COMPUTE WS-EL-MM   = WS-EL-TEMP / 60
    COMPUTE WS-EL-SS   = WS-EL-TEMP - WS-EL-MM * 60
    DISPLAY WS-EL-HH ":" WS-EL-MM ":" WS-EL-SS
    STOP RUN.
' "00:01:13"

run_cobol "3600 elapsed secs → 01:00:00" '
>>SOURCE FORMAT IS FREE
IDENTIFICATION DIVISION. PROGRAM-ID. T5.
DATA DIVISION. WORKING-STORAGE SECTION.
01 WS-ELAPSED-SEC  PIC 9(5) VALUE 3600.
01 WS-EL-HH        PIC 99   VALUE 0.
01 WS-EL-MM        PIC 99   VALUE 0.
01 WS-EL-SS        PIC 99   VALUE 0.
01 WS-EL-TEMP      PIC 9(5) VALUE 0.
PROCEDURE DIVISION.
    COMPUTE WS-EL-HH   = WS-ELAPSED-SEC / 3600
    COMPUTE WS-EL-TEMP = WS-ELAPSED-SEC - WS-EL-HH * 3600
    COMPUTE WS-EL-MM   = WS-EL-TEMP / 60
    COMPUTE WS-EL-SS   = WS-EL-TEMP - WS-EL-MM * 60
    DISPLAY WS-EL-HH ":" WS-EL-MM ":" WS-EL-SS
    STOP RUN.
' "01:00:00"

#==============================================================================
header "PROGRESS BAR — filled vs empty segments"
#==============================================================================

run_cobol "50% through → 32 filled, 33 empty (BAR-WIDTH=65)" '
>>SOURCE FORMAT IS FREE
IDENTIFICATION DIVISION. PROGRAM-ID. T6.
DATA DIVISION. WORKING-STORAGE SECTION.
01 WS-ELAPSED-SEC  PIC 9(5) VALUE 3474.
01 WS-DURATION-SEC PIC 9(5) VALUE 6948.
01 WS-BAR-WIDTH    PIC 99   VALUE 65.
01 WS-BAR-FILLED   PIC 99   VALUE 0.
01 WS-BAR-EMPTY    PIC 99   VALUE 0.
PROCEDURE DIVISION.
    COMPUTE WS-BAR-FILLED =
        (WS-ELAPSED-SEC * WS-BAR-WIDTH) / WS-DURATION-SEC
    COMPUTE WS-BAR-EMPTY = WS-BAR-WIDTH - WS-BAR-FILLED
    DISPLAY WS-BAR-FILLED " " WS-BAR-EMPTY
    STOP RUN.
' "32 33"

run_cobol "0% → 0 filled, 65 empty" '
>>SOURCE FORMAT IS FREE
IDENTIFICATION DIVISION. PROGRAM-ID. T7.
DATA DIVISION. WORKING-STORAGE SECTION.
01 WS-ELAPSED-SEC  PIC 9(5) VALUE 0.
01 WS-DURATION-SEC PIC 9(5) VALUE 6948.
01 WS-BAR-WIDTH    PIC 99   VALUE 65.
01 WS-BAR-FILLED   PIC 99   VALUE 0.
01 WS-BAR-EMPTY    PIC 99   VALUE 0.
PROCEDURE DIVISION.
    COMPUTE WS-BAR-FILLED =
        (WS-ELAPSED-SEC * WS-BAR-WIDTH) / WS-DURATION-SEC
    COMPUTE WS-BAR-EMPTY = WS-BAR-WIDTH - WS-BAR-FILLED
    DISPLAY WS-BAR-FILLED " " WS-BAR-EMPTY
    STOP RUN.
' "00 65"

run_cobol "100% → 65 filled, 0 empty" '
>>SOURCE FORMAT IS FREE
IDENTIFICATION DIVISION. PROGRAM-ID. T8.
DATA DIVISION. WORKING-STORAGE SECTION.
01 WS-ELAPSED-SEC  PIC 9(5) VALUE 6948.
01 WS-DURATION-SEC PIC 9(5) VALUE 6948.
01 WS-BAR-WIDTH    PIC 99   VALUE 65.
01 WS-BAR-FILLED   PIC 99   VALUE 0.
01 WS-BAR-EMPTY    PIC 99   VALUE 0.
PROCEDURE DIVISION.
    COMPUTE WS-BAR-FILLED =
        (WS-ELAPSED-SEC * WS-BAR-WIDTH) / WS-DURATION-SEC
    COMPUTE WS-BAR-EMPTY = WS-BAR-WIDTH - WS-BAR-FILLED
    DISPLAY WS-BAR-FILLED " " WS-BAR-EMPTY
    STOP RUN.
' "65 00"

run_cobol "DURATION=0 guard → 0 filled (no divide-by-zero)" '
>>SOURCE FORMAT IS FREE
IDENTIFICATION DIVISION. PROGRAM-ID. T9.
DATA DIVISION. WORKING-STORAGE SECTION.
01 WS-ELAPSED-SEC  PIC 9(5) VALUE 100.
01 WS-DURATION-SEC PIC 9(5) VALUE 0.
01 WS-BAR-WIDTH    PIC 99   VALUE 65.
01 WS-BAR-FILLED   PIC 99   VALUE 0.
PROCEDURE DIVISION.
    IF WS-DURATION-SEC > 0
        COMPUTE WS-BAR-FILLED =
            (WS-ELAPSED-SEC * WS-BAR-WIDTH) / WS-DURATION-SEC
    ELSE
        MOVE 0 TO WS-BAR-FILLED
    END-IF
    DISPLAY WS-BAR-FILLED
    STOP RUN.
' "00"

#==============================================================================
header "FIND-ACTIVE-CHAPTER — elapsed sec maps to correct chapter"
#==============================================================================

run_cobol "56s elapsed → chapter 2 (starts 00:56)" '
>>SOURCE FORMAT IS FREE
IDENTIFICATION DIVISION. PROGRAM-ID. T10.
DATA DIVISION. WORKING-STORAGE SECTION.
01 WS-ELAPSED-SEC PIC 9(5) VALUE 56.
01 WS-CH-CNT      PIC 99   VALUE 4.
01 WS-ACTIVE-CHAP PIC 99   VALUE 1.
01 WS-WAVE-IDX    PIC 99   VALUE 0.
01 WS-CHAPTERS.
   05 WS-CH OCCURS 4 TIMES.
      10 WS-CH-SEC PIC 9(5).
PROCEDURE DIVISION.
    MOVE 0    TO WS-CH-SEC(1)
    MOVE 56   TO WS-CH-SEC(2)
    MOVE 220  TO WS-CH-SEC(3)
    MOVE 1140 TO WS-CH-SEC(4)
    PERFORM VARYING WS-WAVE-IDX FROM WS-CH-CNT BY -1
        UNTIL WS-WAVE-IDX = 0
        IF WS-ELAPSED-SEC >= WS-CH-SEC(WS-WAVE-IDX)
            MOVE WS-WAVE-IDX TO WS-ACTIVE-CHAP
            EXIT PERFORM
        END-IF
    END-PERFORM
    DISPLAY WS-ACTIVE-CHAP
    STOP RUN.
' "02"

run_cobol "0s elapsed → chapter 1 (intro)" '
>>SOURCE FORMAT IS FREE
IDENTIFICATION DIVISION. PROGRAM-ID. T11.
DATA DIVISION. WORKING-STORAGE SECTION.
01 WS-ELAPSED-SEC PIC 9(5) VALUE 0.
01 WS-CH-CNT      PIC 99   VALUE 4.
01 WS-ACTIVE-CHAP PIC 99   VALUE 1.
01 WS-WAVE-IDX    PIC 99   VALUE 0.
01 WS-CHAPTERS.
   05 WS-CH OCCURS 4 TIMES.
      10 WS-CH-SEC PIC 9(5).
PROCEDURE DIVISION.
    MOVE 0    TO WS-CH-SEC(1)
    MOVE 56   TO WS-CH-SEC(2)
    MOVE 220  TO WS-CH-SEC(3)
    MOVE 1140 TO WS-CH-SEC(4)
    PERFORM VARYING WS-WAVE-IDX FROM WS-CH-CNT BY -1
        UNTIL WS-WAVE-IDX = 0
        IF WS-ELAPSED-SEC >= WS-CH-SEC(WS-WAVE-IDX)
            MOVE WS-WAVE-IDX TO WS-ACTIVE-CHAP
            EXIT PERFORM
        END-IF
    END-PERFORM
    DISPLAY WS-ACTIVE-CHAP
    STOP RUN.
' "01"

run_cobol "9999s elapsed → last chapter (chapter 4)" '
>>SOURCE FORMAT IS FREE
IDENTIFICATION DIVISION. PROGRAM-ID. T12.
DATA DIVISION. WORKING-STORAGE SECTION.
01 WS-ELAPSED-SEC PIC 9(5) VALUE 9999.
01 WS-CH-CNT      PIC 99   VALUE 4.
01 WS-ACTIVE-CHAP PIC 99   VALUE 1.
01 WS-WAVE-IDX    PIC 99   VALUE 0.
01 WS-CHAPTERS.
   05 WS-CH OCCURS 4 TIMES.
      10 WS-CH-SEC PIC 9(5).
PROCEDURE DIVISION.
    MOVE 0    TO WS-CH-SEC(1)
    MOVE 56   TO WS-CH-SEC(2)
    MOVE 220  TO WS-CH-SEC(3)
    MOVE 1140 TO WS-CH-SEC(4)
    PERFORM VARYING WS-WAVE-IDX FROM WS-CH-CNT BY -1
        UNTIL WS-WAVE-IDX = 0
        IF WS-ELAPSED-SEC >= WS-CH-SEC(WS-WAVE-IDX)
            MOVE WS-WAVE-IDX TO WS-ACTIVE-CHAP
            EXIT PERFORM
        END-IF
    END-PERFORM
    DISPLAY WS-ACTIVE-CHAP
    STOP RUN.
' "04"

#==============================================================================
header "CALC-PAGE-BOUNDS — pagination math"
#==============================================================================

run_cobol "page 1, 50 episodes → start=1 end=12 items=12" '
>>SOURCE FORMAT IS FREE
IDENTIFICATION DIVISION. PROGRAM-ID. T13.
DATA DIVISION. WORKING-STORAGE SECTION.
01 WS-PAGE-SIZE   PIC 99 VALUE 12.
01 WS-PAGE-NUM    PIC 99 VALUE 1.
01 WS-EP-CNT      PIC 99 VALUE 50.
01 WS-PAGE-START  PIC 99 VALUE 0.
01 WS-PAGE-END    PIC 99 VALUE 0.
01 WS-PAGE-ITEMS  PIC 99 VALUE 0.
PROCEDURE DIVISION.
    COMPUTE WS-PAGE-START = (WS-PAGE-NUM - 1) * WS-PAGE-SIZE + 1
    COMPUTE WS-PAGE-END   = WS-PAGE-NUM * WS-PAGE-SIZE
    IF WS-PAGE-END > WS-EP-CNT MOVE WS-EP-CNT TO WS-PAGE-END END-IF
    COMPUTE WS-PAGE-ITEMS = WS-PAGE-END - WS-PAGE-START + 1
    DISPLAY WS-PAGE-START " " WS-PAGE-END " " WS-PAGE-ITEMS
    STOP RUN.
' "01 12 12"

run_cobol "last page with 6 episodes → start=49 end=50? no — 6 total, page 1" '
>>SOURCE FORMAT IS FREE
IDENTIFICATION DIVISION. PROGRAM-ID. T14.
DATA DIVISION. WORKING-STORAGE SECTION.
01 WS-PAGE-SIZE   PIC 99 VALUE 12.
01 WS-PAGE-NUM    PIC 99 VALUE 1.
01 WS-EP-CNT      PIC 99 VALUE 6.
01 WS-PAGE-START  PIC 99 VALUE 0.
01 WS-PAGE-END    PIC 99 VALUE 0.
01 WS-PAGE-ITEMS  PIC 99 VALUE 0.
PROCEDURE DIVISION.
    COMPUTE WS-PAGE-START = (WS-PAGE-NUM - 1) * WS-PAGE-SIZE + 1
    COMPUTE WS-PAGE-END   = WS-PAGE-NUM * WS-PAGE-SIZE
    IF WS-PAGE-END > WS-EP-CNT MOVE WS-EP-CNT TO WS-PAGE-END END-IF
    COMPUTE WS-PAGE-ITEMS = WS-PAGE-END - WS-PAGE-START + 1
    DISPLAY WS-PAGE-START " " WS-PAGE-END " " WS-PAGE-ITEMS
    STOP RUN.
' "01 06 06"

#==============================================================================
header "EXTRACT-EP-NUMBER — pulls leading digits from title"
#==============================================================================

run_cobol "title '479: Foo Bar' → ep number 479" '
>>SOURCE FORMAT IS FREE
IDENTIFICATION DIVISION. PROGRAM-ID. T15.
DATA DIVISION. WORKING-STORAGE SECTION.
01 WS-CURR-TTL  PIC X(50) VALUE "479: Autenticar o Que E Autentico".
01 WS-NUM-RAW   PIC X(10) VALUE SPACES.
01 WS-NUM-OUT   PIC 99    VALUE 0.
01 WS-NUM-IDX   PIC 99    VALUE 0.
01 WS-CHAR      PIC X     VALUE SPACES.
01 WS-EP-NUM    PIC X(3)  VALUE SPACES.
PROCEDURE DIVISION.
    PERFORM VARYING WS-NUM-IDX FROM 1 BY 1
        UNTIL WS-NUM-IDX > 5 OR WS-NUM-OUT >= 3
        MOVE WS-CURR-TTL(WS-NUM-IDX:1) TO WS-CHAR
        IF WS-CHAR >= "0" AND WS-CHAR <= "9"
            ADD 1 TO WS-NUM-OUT
            MOVE WS-CHAR TO WS-NUM-RAW(WS-NUM-OUT:1)
        END-IF
    END-PERFORM
    IF WS-NUM-OUT > 0
        MOVE WS-NUM-RAW(1:3) TO WS-EP-NUM
    ELSE
        MOVE "---" TO WS-EP-NUM
    END-IF
    DISPLAY WS-EP-NUM
    STOP RUN.
' "479"

run_cobol "title with no leading number → ---" '
>>SOURCE FORMAT IS FREE
IDENTIFICATION DIVISION. PROGRAM-ID. T16.
DATA DIVISION. WORKING-STORAGE SECTION.
01 WS-CURR-TTL  PIC X(50) VALUE "Special: Year in Review".
01 WS-NUM-RAW   PIC X(10) VALUE SPACES.
01 WS-NUM-OUT   PIC 99    VALUE 0.
01 WS-NUM-IDX   PIC 99    VALUE 0.
01 WS-CHAR      PIC X     VALUE SPACES.
01 WS-EP-NUM    PIC X(3)  VALUE SPACES.
PROCEDURE DIVISION.
    PERFORM VARYING WS-NUM-IDX FROM 1 BY 1
        UNTIL WS-NUM-IDX > 5 OR WS-NUM-OUT >= 3
        MOVE WS-CURR-TTL(WS-NUM-IDX:1) TO WS-CHAR
        IF WS-CHAR >= "0" AND WS-CHAR <= "9"
            ADD 1 TO WS-NUM-OUT
            MOVE WS-CHAR TO WS-NUM-RAW(WS-NUM-OUT:1)
        END-IF
    END-PERFORM
    IF WS-NUM-OUT > 0
        MOVE WS-NUM-RAW(1:3) TO WS-EP-NUM
    ELSE
        MOVE "---" TO WS-EP-NUM
    END-IF
    DISPLAY WS-EP-NUM
    STOP RUN.
' "---"

#==============================================================================
echo ""
echo "══════════════════════════════════════════"
TOTAL=$((PASS+FAIL))
echo -e "  Results: ${GREEN}$PASS passed${RESET}  ${RED}$FAIL failed${RESET}  ($TOTAL total)"
echo "══════════════════════════════════════════"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
