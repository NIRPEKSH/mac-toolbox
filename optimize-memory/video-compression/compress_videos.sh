#!/usr/bin/env bash
#
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  VIDEO COMPRESSOR — H.265 (HEVC)                                       ║
# ║                                                                         ║
# ║  Usage:                                                                 ║
# ║    1. Copy this script into any folder containing video files           ║
# ║    2. Open terminal, cd to that folder                                  ║
# ║    3. Run: ./compress_videos.sh                                         ║
# ║                                                                         ║
# ║  What it does:                                                          ║
# ║    - Re-encodes all videos to H.265/HEVC (much better compression)      ║
# ║    - Runs multiple encodes in parallel (auto-detects your CPU)          ║
# ║    - Shows live progress every 5 minutes                                ║
# ║    - Moves originals to an "originals/" subfolder (not deleted)         ║
# ║    - Prints a full summary at the end                                   ║
# ║                                                                         ║
# ║  Supported formats: mp4, mkv, avi, mov, wmv, flv, webm, m4v, mpg       ║
# ║                                                                         ║
# ║  PRIVACY: This script runs 100% locally on your machine.               ║
# ║  No data is sent over the network. No telemetry. No analytics.         ║
# ║  Your files never leave your computer.                                  ║
# ║                                                                         ║
# ║  Source: https://github.com/NIRPEKSH/mac-toolbox                       ║
# ╚══════════════════════════════════════════════════════════════════════════╝
#

# Exit on errors, undefined variables, and pipe failures
set -euo pipefail


# ═══════════════════════════════════════════════════════════════════════════
# CONFIG — Change these to tune compression behavior
# ═══════════════════════════════════════════════════════════════════════════

# CRF = Constant Rate Factor (quality target)
#   Lower = better quality but bigger file. Higher = smaller but worse.
#   18 = visually lossless (huge files)
#   23 = high quality (good balance)
#   28 = great quality, much smaller (recommended — hard to see any loss)
#   32 = noticeable softness on close inspection
CRF=28

# PRESET = How hard the encoder tries to pack bits efficiently
#   All presets target the SAME quality (CRF controls that).
#   Slower presets just achieve that quality in fewer bytes.
#
#   ultrafast  — ~10x faster than medium, files ~40-50% larger
#   veryfast   — ~3-4x faster, files ~15-20% larger
#   fast       — ~2x faster, files ~5-8% larger
#   medium     — baseline speed and size
#   slow       — ~2x slower, files ~5-8% smaller
#   slower     — ~4-5x slower, files ~10-12% smaller
#   veryslow   — ~10-15x slower, files ~12-15% smaller (maximum compression)
PRESET=veryslow

# Audio bitrate — 128k is CD quality stereo, no need to go higher for most content
AUDIO_BITRATE=128k

# How often to print progress updates (in seconds). Default: 300 = every 5 min
PROGRESS_INTERVAL=300


# ═══════════════════════════════════════════════════════════════════════════
# AUTO-DETECT SYSTEM — figures out how many parallel jobs your CPU can handle
# ═══════════════════════════════════════════════════════════════════════════

# Get total CPU cores (macOS: sysctl, Linux: nproc)
TOTAL_CORES=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)

# Heavier presets need more cores per encode job
# veryslow/slower: 4 cores each | slow/medium: 3 each | fast and above: 2 each
if [ "$PRESET" = "veryslow" ] || [ "$PRESET" = "slower" ]; then
    CORES_PER_JOB=4
elif [ "$PRESET" = "slow" ] || [ "$PRESET" = "medium" ]; then
    CORES_PER_JOB=3
else
    CORES_PER_JOB=2
fi

# Calculate how many videos we can encode at once
MAX_PARALLEL=$((TOTAL_CORES / CORES_PER_JOB))
[ "$MAX_PARALLEL" -lt 1 ] && MAX_PARALLEL=1

# Get total RAM for display
TOTAL_RAM=$(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.0f", $0/1024/1024/1024}' 2>/dev/null || echo "?")
CPU_NAME=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown CPU")


# ═══════════════════════════════════════════════════════════════════════════
# FIND VIDEO FILES — scans current folder for all supported video formats
# ═══════════════════════════════════════════════════════════════════════════

# Resolve the folder where this script lives (so you can run it from anywhere)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Collect all video files, excluding any previously compressed "_h265" files
VIDEO_FILES=()
while IFS= read -r -d '' file; do
    VIDEO_FILES+=("$file")
done < <(find . -maxdepth 1 -type f \( \
    -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.mov" \
    -o -iname "*.wmv" -o -iname "*.flv" -o -iname "*.webm" -o -iname "*.m4v" \
    -o -iname "*.ts" -o -iname "*.mpg" -o -iname "*.mpeg" \
\) -not -iname "*_h265.*" -print0 | sort -z)

# Nothing to do? Exit cleanly
if [ "${#VIDEO_FILES[@]}" -eq 0 ]; then
    echo "No video files found in: $SCRIPT_DIR"
    echo "(Files already ending in _h265 are skipped)"
    exit 0
fi


# ═══════════════════════════════════════════════════════════════════════════
# PRE-FLIGHT CHECKS
# ═══════════════════════════════════════════════════════════════════════════

# Make sure ffmpeg is installed
if ! command -v ffmpeg &>/dev/null; then
    echo "ERROR: ffmpeg is not installed."
    echo ""
    echo "  Install it:"
    echo "    macOS:   brew install ffmpeg"
    echo "    Ubuntu:  sudo apt install ffmpeg"
    echo "    Fedora:  sudo dnf install ffmpeg"
    exit 1
fi

# Check available disk space (need roughly as much free as the largest file)
AVAIL_BYTES=$(df -k "$SCRIPT_DIR" | tail -1 | awk '{print $4 * 1024}')
LARGEST_FILE=0
for f in "${VIDEO_FILES[@]}"; do
    SZ=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null || echo 0)
    [ "$SZ" -gt "$LARGEST_FILE" ] && LARGEST_FILE=$SZ
done
if [ "$AVAIL_BYTES" -lt "$LARGEST_FILE" ]; then
    NEED_GB=$(echo "scale=1; $LARGEST_FILE / 1024 / 1024 / 1024" | bc)
    HAVE_GB=$(echo "scale=1; $AVAIL_BYTES / 1024 / 1024 / 1024" | bc)
    echo "WARNING: Low disk space! Largest file needs ~${NEED_GB} GB temp space, you have ${HAVE_GB} GB free."
    echo "         Compression creates a new file before moving the original."
    echo ""
    read -rp "Continue anyway? (y/N): " REPLY
    [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ] || exit 0
fi


# ═══════════════════════════════════════════════════════════════════════════
# CALCULATE TOTALS — for the summary header and final report
# ═══════════════════════════════════════════════════════════════════════════

TOTAL_ORIG_SIZE=0
for f in "${VIDEO_FILES[@]}"; do
    SIZE=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null || echo 0)
    TOTAL_ORIG_SIZE=$((TOTAL_ORIG_SIZE + SIZE))
done

# Human-readable size helper
human_size() {
    local bytes=$1
    if [ "$bytes" -ge 1073741824 ]; then
        echo "$(echo "scale=2; $bytes / 1073741824" | bc) GB"
    else
        echo "$(echo "scale=0; $bytes / 1048576" | bc) MB"
    fi
}

# Format seconds as "Xh Ym Zs"
format_time() {
    local secs=$1
    local h=$((secs / 3600))
    local m=$(( (secs % 3600) / 60 ))
    local s=$((secs % 60))
    if [ "$h" -gt 0 ]; then
        printf "%dh %dm %ds" "$h" "$m" "$s"
    elif [ "$m" -gt 0 ]; then
        printf "%dm %ds" "$m" "$s"
    else
        printf "%ds" "$s"
    fi
}


# ═══════════════════════════════════════════════════════════════════════════
# PRINT START BANNER
# ═══════════════════════════════════════════════════════════════════════════

TOTAL_COUNT=${#VIDEO_FILES[@]}

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  VIDEO COMPRESSOR — H.265 HEVC                                 ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║                                                                 ║"
printf "║  %-62s║\n" "Folder:  $SCRIPT_DIR"
printf "║  %-62s║\n" "Files:   $TOTAL_COUNT videos ($(human_size $TOTAL_ORIG_SIZE))"
printf "║  %-62s║\n" "Preset:  $PRESET (CRF $CRF)"
printf "║  %-62s║\n" "CPU:     $CPU_NAME"
printf "║  %-62s║\n" "Cores:   $TOTAL_CORES cores, ${TOTAL_RAM} GB RAM"
printf "║  %-62s║\n" "Workers: $MAX_PARALLEL parallel slots (job queue)"
echo "║                                                                 ║"
echo "║  *** 100% LOCAL — no data leaves your machine ***               ║"
echo "║                                                                 ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# List all files that will be processed
echo "Files to compress:"
for f in "${VIDEO_FILES[@]}"; do
    fname=$(basename "$f")
    fsize=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null || echo 0)
    # Get video duration using ffprobe
    dur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$f" 2>/dev/null || echo "0")
    dur_min=$(echo "scale=1; ${dur:-0} / 60" | bc 2>/dev/null || echo "?")
    printf "  %-60s %8s  %s min\n" "$fname" "$(human_size $fsize)" "$dur_min"
done
echo ""

# Create originals folder to store pre-compression files
mkdir -p originals

# Shared temp directory for progress tracking between parallel jobs
PROGRESS_DIR=$(mktemp -d)
trap 'rm -rf "$PROGRESS_DIR"' EXIT


# ═══════════════════════════════════════════════════════════════════════════
# COMPRESS ONE FILE — this function runs once per video (possibly in parallel)
# ═══════════════════════════════════════════════════════════════════════════

compress_one() {
    local input="$1"
    local file_num="$2"          # e.g. "3/7" for display
    local filename=$(basename "$input")
    local name="${filename%.*}"
    local ext="${filename##*.}"
    local output="./${name}_h265_temp.${ext}"
    local start_time=$(date +%s)

    # Get original file size
    local orig_size=$(stat -f%z "$input" 2>/dev/null || stat -c%s "$input" 2>/dev/null)
    local orig_hr=$(human_size "$orig_size")

    # Get video duration for ETA estimation
    local duration=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$input" 2>/dev/null || echo "0")
    local dur_min=$(echo "scale=1; ${duration:-0} / 60" | bc 2>/dev/null || echo "?")

    echo ""
    echo "┌──────────────────────────────────────────────────────────────"
    echo "│ [$file_num] ENCODING: $filename"
    echo "│ Size: $orig_hr | Duration: ${dur_min} min | Preset: $PRESET"
    echo "└──────────────────────────────────────────────────────────────"

    # Write a status file so the progress monitor can read it
    echo "encoding|$filename|$start_time|$duration" > "$PROGRESS_DIR/$$_$(basename "$input" | tr ' ' '_')"

    # ── The actual ffmpeg encode ──
    # -c:v libx265    = use H.265/HEVC video codec
    # -crf $CRF       = quality target (28 = great quality, small size)
    # -preset $PRESET = how hard to try (veryslow = smallest files)
    # -c:a aac        = re-encode audio as AAC
    # -b:a 128k       = audio bitrate (128kbps = CD quality)
    # -tag:v hvc1     = compatibility tag so Apple devices can play it
    # -movflags       = put file index at start so video can stream/seek immediately
    # -threads        = limit CPU cores per job so parallel encodes don't fight
    # 2>"$log"        = capture ffmpeg progress output for monitoring
    local log="$PROGRESS_DIR/log_$$_$(basename "$input" | tr ' ' '_')"
    ffmpeg -y -i "$input" \
        -c:v libx265 \
        -crf "$CRF" \
        -preset "$PRESET" \
        -c:a aac -b:a "$AUDIO_BITRATE" \
        -tag:v hvc1 \
        -movflags +faststart \
        -threads "$CORES_PER_JOB" \
        "$output" \
        </dev/null 2>"$log"
    local exit_code=$?

    # Check if encode succeeded and output file exists
    if [ $exit_code -eq 0 ] && [ -f "$output" ]; then
        local new_size=$(stat -f%z "$output" 2>/dev/null || stat -c%s "$output" 2>/dev/null)
        local new_hr=$(human_size "$new_size")
        local saved_pct=$(echo "scale=1; (1 - $new_size / $orig_size) * 100" | bc)
        local elapsed=$(( $(date +%s) - start_time ))

        # Move original to safety, replace with compressed version
        mv "$input" "originals/$filename"
        mv "$output" "./$filename"

        # Mark as done in progress tracker
        echo "done|$filename|$orig_size|$new_size|$elapsed" > "$PROGRESS_DIR/$$_$(basename "$input" | tr ' ' '_')"

        echo ""
        echo "┌──────────────────────────────────────────────────────────────"
        echo "│ [$file_num] DONE: $filename"
        echo "│ $orig_hr  →  $new_hr  (${saved_pct}% smaller)"
        echo "│ Time: $(format_time $elapsed)"
        echo "└──────────────────────────────────────────────────────────────"
    else
        # Encode failed — clean up partial output, keep original untouched
        echo ""
        echo "│ [$file_num] FAILED: $filename — keeping original"
        rm -f "$output"
        echo "fail|$filename" > "$PROGRESS_DIR/$$_$(basename "$input" | tr ' ' '_')"
    fi

    rm -f "$log"
}

# Export function and variables so background subshells (parallel jobs) can use them
export -f compress_one human_size format_time
export CRF PRESET AUDIO_BITRATE CORES_PER_JOB PROGRESS_DIR


# ═══════════════════════════════════════════════════════════════════════════
# PROGRESS MONITOR — runs in background, prints status every 5 minutes
# ═══════════════════════════════════════════════════════════════════════════

progress_monitor() {
    local total=$1
    local global_start=$2

    while true; do
        sleep "$PROGRESS_INTERVAL"

        # Count completed and in-progress jobs from the progress directory
        local done_count=0
        local done_saved=0
        local active_files=""

        for pf in "$PROGRESS_DIR"/*; do
            [ -f "$pf" ] || continue
            local status=$(cut -d'|' -f1 "$pf")
            if [ "$status" = "done" ]; then
                done_count=$((done_count + 1))
                local orig_s=$(cut -d'|' -f3 "$pf")
                local new_s=$(cut -d'|' -f4 "$pf")
                done_saved=$((done_saved + orig_s - new_s))
            elif [ "$status" = "encoding" ]; then
                local fname=$(cut -d'|' -f2 "$pf")
                local stime=$(cut -d'|' -f3 "$pf")
                local fdur=$(cut -d'|' -f4 "$pf")
                local elapsed=$(( $(date +%s) - stime ))
                local elapsed_hr=$(format_time $elapsed)

                # Estimate remaining time based on duration and elapsed
                local eta_str="calculating..."
                if [ "$(echo "$fdur > 0" | bc 2>/dev/null)" = "1" ] && [ "$elapsed" -gt 60 ]; then
                    # Check how far ffmpeg has gotten by looking at output file size growth rate
                    local pct_est=$(echo "scale=0; $elapsed * 100 / ($fdur * 3)" | bc 2>/dev/null || echo "")
                    if [ -n "$pct_est" ] && [ "$pct_est" -gt 0 ] 2>/dev/null; then
                        [ "$pct_est" -gt 99 ] && pct_est=99
                        local remain=$(echo "scale=0; $elapsed * (100 - $pct_est) / $pct_est" | bc 2>/dev/null || echo "")
                        [ -n "$remain" ] && eta_str="~$(format_time $remain) left"
                    fi
                fi

                active_files="${active_files}    ⚙  ${fname} — running ${elapsed_hr}, ${eta_str}\n"
            fi
        done

        local total_elapsed=$(( $(date +%s) - global_start ))

        # Print progress update
        echo ""
        echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "┃ PROGRESS UPDATE ($(date '+%H:%M:%S'))"
        echo "┃ Total elapsed: $(format_time $total_elapsed)"
        echo "┃ Completed: $done_count / $total files | Saved so far: $(human_size $done_saved)"
        if [ -n "$active_files" ]; then
            echo "┃ Currently encoding:"
            printf "┃ $active_files"
        fi
        echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
    done
}

export -f progress_monitor


# ═══════════════════════════════════════════════════════════════════════════
# MAIN LOOP — job queue with N worker slots
# ═══════════════════════════════════════════════════════════════════════════
#
# Instead of fixed batches (where a fast file finishes and its slot sits idle
# until the slow file in the same batch completes), we use a job queue:
#
#   - Maintain N worker slots running at all times
#   - The moment ANY file finishes, the next file from the queue starts
#   - No CPU time is wasted waiting for a batch to complete
#
# Example with 2 slots and files of 60min, 15min, 40min, 20min:
#
#   Old (fixed batches):
#     Batch 1: [60min] [15min] → slot 2 idle for 45min → total ~100min
#     Batch 2: [40min] [20min] → slot 2 idle for 20min
#
#   New (job queue):
#     Slot 1: [60min]          [20min]    → total ~80min
#     Slot 2: [15min] [40min]  [done]
#     The 40min file starts as soon as the 15min file finishes!

GLOBAL_START=$(date +%s)

# Start the progress monitor in the background
progress_monitor "$TOTAL_COUNT" "$GLOBAL_START" &
MONITOR_PID=$!

# Make sure we kill the monitor when the script exits (normal or error)
cleanup() {
    kill "$MONITOR_PID" 2>/dev/null
    wait "$MONITOR_PID" 2>/dev/null
    rm -rf "$PROGRESS_DIR"
}
trap cleanup EXIT

echo "Starting compression: $TOTAL_COUNT files, $MAX_PARALLEL worker slots (job queue)..."
echo "(When a file finishes, the next one starts immediately — no wasted time)"

# NEXT_INDEX tracks which file to hand out next from the queue
NEXT_INDEX=0

# ACTIVE_PIDS is a simple space-separated list of PIDs (bash 3.2 compatible)
# We avoid 'declare -A' (associative arrays) because macOS ships bash 3.2
ACTIVE_PIDS=""

# Helper: count words in ACTIVE_PIDS (= number of running workers)
count_active() { echo $ACTIVE_PIDS | wc -w | tr -d ' '; }

# Helper: remove a PID from the active list
remove_pid() {
    local remove=$1
    local new_list=""
    for p in $ACTIVE_PIDS; do
        [ "$p" != "$remove" ] && new_list="$new_list $p"
    done
    ACTIVE_PIDS="$new_list"
}

# Seed the initial worker slots (up to MAX_PARALLEL or total files, whichever is smaller)
while [ $NEXT_INDEX -lt $TOTAL_COUNT ] && [ "$(count_active)" -lt $MAX_PARALLEL ]; do
    compress_one "${VIDEO_FILES[$NEXT_INDEX]}" "$((NEXT_INDEX + 1))/$TOTAL_COUNT" &
    ACTIVE_PIDS="$ACTIVE_PIDS $!"
    NEXT_INDEX=$((NEXT_INDEX + 1))
done

# Main queue loop: wait for ANY worker to finish, then launch the next file
while [ "$(count_active)" -gt 0 ]; do
    # Poll each active PID to find which one finished
    # (bash 3.2 doesn't support 'wait -n', so we check manually)
    FINISHED_PID=""
    while [ -z "$FINISHED_PID" ]; do
        for pid in $ACTIVE_PIDS; do
            if ! kill -0 "$pid" 2>/dev/null; then
                # This PID is no longer running — it finished
                wait "$pid" 2>/dev/null || true
                FINISHED_PID=$pid
                break
            fi
        done
        # Brief sleep to avoid busy-waiting (0.5s is plenty — encodes take minutes)
        [ -z "$FINISHED_PID" ] && sleep 0.5
    done

    # Remove the finished worker from the active list
    remove_pid "$FINISHED_PID"

    # If there are more files in the queue, launch the next one immediately
    if [ $NEXT_INDEX -lt $TOTAL_COUNT ]; then
        compress_one "${VIDEO_FILES[$NEXT_INDEX]}" "$((NEXT_INDEX + 1))/$TOTAL_COUNT" &
        ACTIVE_PIDS="$ACTIVE_PIDS $!"
        NEXT_INDEX=$((NEXT_INDEX + 1))
    fi
done

# Stop the progress monitor
kill "$MONITOR_PID" 2>/dev/null || true
wait "$MONITOR_PID" 2>/dev/null || true

GLOBAL_END=$(date +%s)
GLOBAL_ELAPSED=$((GLOBAL_END - GLOBAL_START))


# ═══════════════════════════════════════════════════════════════════════════
# FINAL SUMMARY — show before/after for every file and the grand total
# ═══════════════════════════════════════════════════════════════════════════

echo ""
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    COMPRESSION COMPLETE                         ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║                                                                 ║"

# Per-file breakdown
FINAL_ORIG_TOTAL=0
FINAL_NEW_TOTAL=0
DONE_COUNT=0
FAIL_COUNT=0

for pf in "$PROGRESS_DIR"/*; do
    [ -f "$pf" ] || continue
    status=$(cut -d'|' -f1 "$pf")
    fname=$(cut -d'|' -f2 "$pf")

    if [ "$status" = "done" ]; then
        orig_s=$(cut -d'|' -f3 "$pf")
        new_s=$(cut -d'|' -f4 "$pf")
        elapsed_s=$(cut -d'|' -f5 "$pf")
        saved_pct=$(echo "scale=1; (1 - $new_s / $orig_s) * 100" | bc)
        FINAL_ORIG_TOTAL=$((FINAL_ORIG_TOTAL + orig_s))
        FINAL_NEW_TOTAL=$((FINAL_NEW_TOTAL + new_s))
        DONE_COUNT=$((DONE_COUNT + 1))
        printf "║  ✓ %-44s %8s → %8s  (%s%%)  ║\n" \
            "$(echo "$fname" | cut -c1-44)" \
            "$(human_size $orig_s)" \
            "$(human_size $new_s)" \
            "$saved_pct"
    elif [ "$status" = "fail" ]; then
        FAIL_COUNT=$((FAIL_COUNT + 1))
        printf "║  ✗ %-44s FAILED %22s  ║\n" "$(echo "$fname" | cut -c1-44)" ""
    fi
done

FINAL_SAVED=$((FINAL_ORIG_TOTAL - FINAL_NEW_TOTAL))
if [ "$FINAL_ORIG_TOTAL" -gt 0 ]; then
    TOTAL_SAVED_PCT=$(echo "scale=1; $FINAL_SAVED * 100 / $FINAL_ORIG_TOTAL" | bc)
else
    TOTAL_SAVED_PCT="0"
fi

echo "║                                                                 ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║                                                                 ║"
printf "║  Total before:      %-44s║\n" "$(human_size $FINAL_ORIG_TOTAL)"
printf "║  Total after:       %-44s║\n" "$(human_size $FINAL_NEW_TOTAL)"
printf "║  Space saved:       %-44s║\n" "$(human_size $FINAL_SAVED) (${TOTAL_SAVED_PCT}%)"
printf "║  Files processed:   %-44s║\n" "$DONE_COUNT succeeded, $FAIL_COUNT failed"
printf "║  Total time:        %-44s║\n" "$(format_time $GLOBAL_ELAPSED)"
echo "║                                                                 ║"
printf "║  Originals saved in: %-43s║\n" "originals/"
echo "║  (delete that folder once you're happy with the results)        ║"
echo "║                                                                 ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
