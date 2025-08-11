#!/bin/bash
set -euo pipefail

VIDEO_URL="https://drive.google.com/file/d/1jImUISz6RVDlfqxrkI2opNUTvy5sHJQd/view?usp=sharing"
RAM_VIDEO="/dev/shm/latest_video.mp4"
TMP_VIDEO="/dev/shm/tmp_video.mp4"
FALLBACK_VIDEO="/home/yaroslav/fallback.mp4"
LOG="/dev/shm/tv.log"

# простий lock, щоб не було паралельних запусків
LOCK="/dev/shm/tv.lock"
exec 9>"$LOCK" || true
flock -n 9 || exit 0

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"
}

cleanup() {
  [ -f "$TMP_VIDEO" ] && rm -f "$TMP_VIDEO"
  rm -f /dev/shm/gd_cookie.txt /dev/shm/gd_page.html 2>/dev/null || true
}

is_gdrive_url() {
  case "$VIDEO_URL" in
    *://drive.google.com/*) return 0 ;;
    *) return 1 ;;
  esac
}

# витягає FILE_ID з /file/d/<ID>/... або ...?id=<ID>
extract_gd_id() {
  local url="$1" id=""
  id="$(echo "$url" | sed -n 's#.*drive\.google\.com.*/file/d/\([^/]*\)/.*#\1#p')"
  [ -n "$id" ] && { echo "$id"; return; }
  id="$(echo "$url" | sed -n 's#.*[?&]id=\([^&]*\).*#\1#p')"
  [ -n "$id" ] && { echo "$id"; return; }
  echo ""
}

# простий тест «схоже на MP4»: шукаємо 'ftyp' в заголовку
looks_like_mp4() {
  head -c 512 "$1" 2>/dev/null | tr -d '\0' | grep -aq 'ftyp'
}

download_from_gdrive() {
  local file_id="$1" out="$2"
  local cookie="/dev/shm/gd_cookie.txt"
  local page="/dev/shm/gd_page.html"
  local base="https://drive.google.com/uc?export=download&id=${file_id}"

  curl -s -L --connect-timeout 10 --max-time 120 -c "$cookie" "$base" -o "$page" || return 1

  if grep -qi 'quota exceeded' "$page"; then
    log "❌ Google Drive quota exceeded"
    return 1
  fi

  local confirm=""
  confirm="$(grep -o 'confirm=[0-9A-Za-z_-]*' "$page" | head -n1 | cut -d= -f2)"

  if [ -n "$confirm" ]; then
    curl -s -L --connect-timeout 10 --max-time 600 -b "$cookie" \
      "https://drive.google.com/uc?export=download&confirm=${confirm}&id=${file_id}" -o "$out"
  else
    curl -s -L --connect-timeout 10 --max-time 600 -b "$cookie" "$base" -o "$out"
  fi

  [ -s "$out" ] && looks_like_mp4 "$out"
}

download_regular() {
  curl -s -L --connect-timeout 10 --max-time 180 "$VIDEO_URL" -o "$TMP_VIDEO"
  [ -s "$TMP_VIDEO" ] && looks_like_mp4 "$TMP_VIDEO"
}

# не стартуємо другий VLC
if pgrep -x cvlc > /dev/null; then
  log "⚠️ cvlc вже запущено — не запускаємо повторно"
  exit 0
fi

log "🌐 Спроба завантажити відео..."
cleanup

ok=0
if is_gdrive_url; then
  FILE_ID="$(extract_gd_id "$VIDEO_URL")"
  if [ -n "$FILE_ID" ] && download_from_gdrive "$FILE_ID" "$TMP_VIDEO"; then
    ok=1
  else
    log "⚠️ Не вдалося завантажити з Google Drive"
  fi
else
  download_regular && ok=1 || log "⚠️ Не вдалося завантажити за прямим URL"
fi

if [ $ok -eq 1 ] && [ -s "$TMP_VIDEO" ]; then
  mv -f "$TMP_VIDEO" "$RAM_VIDEO"
  log "✅ Відео завантажено в RAM"
  SOURCE="$RAM_VIDEO"
else
  if [ -s "$FALLBACK_VIDEO" ]; then
    log "❌ Завантаження не вдалося, використовую fallback"
    SOURCE="$FALLBACK_VIDEO"
  else
    log "❌ Немає fallback відео: $FALLBACK_VIDEO"
    exit 1
  fi
  cleanup
fi

log "▶️ Відтворення: $SOURCE"
/usr/bin/cvlc --repeat --no-audio --fullscreen --no-osd "$SOURCE" >/dev/null 2>&1 &

# CEC — не валимо скрипт, якщо немає cec-client
echo "pow 0" | /usr/bin/cec-client -s -d 1 >/dev/null 2>&1 || true
echo "on 0"  | /usr/bin/cec-client -s -d 1 >/dev/null 2>&1 || true
echo "as"    | /usr/bin/cec-client -s -d 1 >/dev/null 2>&1 || true
