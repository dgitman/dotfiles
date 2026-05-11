#!/bin/bash
# shira_watcher.sh
# Monitors Shira's social media profiles for new content using yt-dlp.
# Runs hourly via launchd. Downloads media to ~/Pictures/Shira with EXIF/QuickTime
# date metadata, then sends an iMessage to david@gitman.net if anything was saved.
#
# Requires: yt-dlp (brew install yt-dlp), exiftool (brew install exiftool)
# Auth:     reads cookies directly from Chrome's local database (Chrome need not be open)

DEST="$HOME/Pictures/Shira"
ARCHIVE_DIR="$HOME/Documents/Claude/Scheduled/shira-social-media-watcher"
TMP_DIR=$(mktemp -d /tmp/shira_watcher.XXXXXX)
LOG="$ARCHIVE_DIR/yt_watcher.log"

mkdir -p "$DEST" "$ARCHIVE_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }
log "=== Run started ==="

declare -a new_files=()
declare -a skipped_platforms=()

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# ---------------------------------------------------------------------------
# finalize_file: apply date metadata, move to ~/Pictures/Shira with collision
# handling.  Args: <source_path> <filename_prefix> <YYYY-MM-DD>
# ---------------------------------------------------------------------------
finalize_file() {
  local src="$1" prefix="$2" date_str="$3"
  local ext="${src##*.}"
  local y="${date_str:0:4}" m="${date_str:5:2}" d="${date_str:8:2}"

  # EXIF / QuickTime metadata
  if command -v exiftool &>/dev/null; then
    case "$ext" in
      jpg|jpeg)
        exiftool -q -overwrite_original \
          "-DateTimeOriginal=${y}:${m}:${d} 12:00:00" \
          "-CreateDate=${y}:${m}:${d} 12:00:00" \
          "-ModifyDate=${y}:${m}:${d} 12:00:00" \
          "$src" 2>/dev/null || true ;;
      mp4|m4v|mov)
        exiftool -q -overwrite_original \
          "-api" "QuickTimeUTC=1" \
          "-CreateDate=${y}:${m}:${d} 12:00:00" \
          "-MediaCreateDate=${y}:${m}:${d} 12:00:00" \
          "-TrackCreateDate=${y}:${m}:${d} 12:00:00" \
          "-ModifyDate=${y}:${m}:${d} 12:00:00" \
          "$src" 2>/dev/null || true ;;
    esac
  fi
  touch -t "${y}${m}${d}1200.00" "$src" 2>/dev/null || true

  # Collision-safe destination name
  local base_name="${prefix}_${date_str}.${ext}"
  local dest="$DEST/$base_name"
  if [[ -f "$dest" ]]; then
    local n=2
    while [[ -f "$DEST/${prefix}_${date_str}_${n}.${ext}" ]]; do ((n++)); done
    base_name="${prefix}_${date_str}_${n}.${ext}"
    dest="$DEST/$base_name"
  fi

  mv "$src" "$dest"
  new_files+=("$base_name")
  log "Saved: $base_name"
}

# ---------------------------------------------------------------------------
# run_ytdlp: download new posts from a profile page.
# Args: <platform_key> <profile_url> <filename_prefix>
# Uses per-platform yt-dlp archive file to skip already-downloaded content.
# ---------------------------------------------------------------------------
run_ytdlp() {
  local platform="$1" url="$2" prefix="$3"
  local archive="$ARCHIVE_DIR/ytdlp_${platform}_archive.txt"
  local platform_dir="$TMP_DIR/$platform"
  mkdir -p "$platform_dir"

  log "Checking $platform..."

  if ! command -v yt-dlp &>/dev/null; then
    log "ERROR: yt-dlp not found — install with: brew install yt-dlp"
    skipped_platforms+=("$platform (yt-dlp missing)")
    return
  fi

  # Output template: YYYY-MM-DD_<id>.<ext> so date is always the first 10 chars.
  # --ignore-errors: a single bad video won't abort the whole playlist.
  local ytdlp_out
  ytdlp_out=$(yt-dlp \
    --cookies-from-browser chrome \
    --download-archive "$archive" \
    --playlist-end 20 \
    --output "$platform_dir/%(upload_date>%Y-%m-%d)s_%(id)s.%(ext)s" \
    --no-warnings \
    --ignore-errors \
    "$url" 2>&1) || true

  if echo "$ytdlp_out" | grep -qi "error\|failed\|unavailable\|blocked\|captcha"; then
    log "WARNING ($platform): $(echo "$ytdlp_out" | grep -i 'error\|failed\|unavailable\|blocked\|captcha' | head -3)"
  fi

  local count=0
  for f in "$platform_dir"/*; do
    [[ -f "$f" ]] || continue
    local fname date_str
    fname=$(basename "$f")
    date_str="${fname:0:10}"   # first 10 chars of YYYY-MM-DD_<id>.<ext>
    if [[ "$date_str" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
      finalize_file "$f" "$prefix" "$date_str"
      ((count++))
    else
      log "WARNING: unexpected filename pattern: $fname (skipping)"
    fi
  done

  if [[ $count -eq 0 ]]; then
    log "No new content for $platform"
  else
    log "$platform: $count new file(s)"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
run_ytdlp "tiktok"    "https://www.tiktok.com/@shira.gitman"   "TIKTOK_shiragitman"
run_ytdlp "instagram" "https://www.instagram.com/shiragitman/" "INSTAGRAM_shiragitman"
run_ytdlp "vsco"      "https://vsco.co/shirajules/gallery"      "VSCO_shirajules"
run_ytdlp "snapchat"  "https://www.snapchat.com/@shira.juless"  "SNAPCHAT_shirajuless"

total="${#new_files[@]}"
log "Run complete — $total new file(s) saved."

# ---------------------------------------------------------------------------
# iMessage notification (only if something was saved)
# ---------------------------------------------------------------------------
if [[ $total -gt 0 ]]; then
  msg="New from Shira ($total save(s)):"$'\n'
  for f in "${new_files[@]}"; do
    msg+="  • $f"$'\n'
  done
  msg+="Saved to ~/Pictures/Shira"
  if [[ ${#skipped_platforms[@]} -gt 0 ]]; then
    msg+=$'\n'"Skipped: $(IFS=', '; echo "${skipped_platforms[*]}")"
  fi

  osascript \
    -e 'on run argv' \
    -e 'tell application "Messages"' \
    -e 'set svc to 1st service whose service type = iMessage' \
    -e 'set buddy to buddy "david@gitman.net" of svc' \
    -e 'send (item 1 of argv) to buddy' \
    -e 'end tell' \
    -e 'end run' \
    -- "$msg" 2>/dev/null \
    && log "iMessage sent" \
    || log "iMessage send failed (non-fatal)"
fi
