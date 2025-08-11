#!/bin/bash

LOG="/dev/shm/tv.log"
VIDEO_SCRIPT="/home/yaroslav/play_video.sh"
WIFI_IFACE="wlan0"
MAX_LOG_LINES=500

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"
    # Обрізаємо лог до останніх 500 рядків
    tail -n $MAX_LOG_LINES "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
}

check_internet() {
    if ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
        log "✅ Інтернет доступний 2.3"
        
        # Спроба синхронізувати час
        if sudo ntpdate -u 0.pool.ntp.org > /dev/null 2>&1; then
            log "🕒 Час синхронізовано через ntpdate"
        else
            log "⚠️ Не вдалося синхронізувати час"
        fi

        return 0
    else
        log "❌ Інтернет недоступний — перезапуск Wi-Fi через rfkill"
        sudo rfkill block wifi
        sleep 5
        sudo rfkill unblock wifi
        sleep 15
        sudo dhclient "$WIFI_IFACE" || true
        return 1
    fi
}

is_tv_on() {
    local status
    status=$(echo "pow 0" | cec-client -s -d 1 | grep "power status")
    if echo "$status" | grep -iq "on"; then
        return 0
    else
        return 1
    fi
}

ping_tv() {
    log "📶 Надіслано CEC ping телевізору"
    echo "ping" | cec-client -s -d 1 > /dev/null 2>&1
}

turn_on_tv() {
    echo "on 0" | cec-client -s -d 1 > /dev/null 2>&1
}

try_turn_on_tv_with_retries() {
    for i in {1..3}; do
        if is_tv_on; then
            return 0
        fi
        log "🔁 Спроба №$i увімкнути телевізор"
        turn_on_tv
        sleep 30
    done
    return 1
}

is_video_playing() {
    pgrep -x vlc > /dev/null
}

stop_video() {
    pkill -x vlc && log "⏹ Зупинено відтворення відео"
}

start_video() {
    if ! is_video_playing; then
        log "▶️ Відео не запущено — запускаємо play_video.sh"
        "$VIDEO_SCRIPT" &
    else
        log "▶️ Відео вже відтворюється"
    fi
}

# === Основна логіка ===

CURRENT_MIN=$(date +%M)
CURRENT_HOUR=$(date +%H)
CURRENT_TIME=$((10#$CURRENT_HOUR * 60 + 10#$CURRENT_MIN))

if [ "$CURRENT_TIME" -ge 480 ] && [ "$CURRENT_TIME" -lt 1200 ]; then
    log "🕗 Робочий час: $CURRENT_HOUR:$CURRENT_MIN"
    check_internet

    if is_tv_on; then
        ping_tv
    else
        try_turn_on_tv_with_retries || log "⚠️ Не вдалося увімкнути телевізор — граємо відео без CEC"
    fi

    start_video
else
    log "🌙 Неробочий час: $CURRENT_HOUR:$CURRENT_MIN — зупиняємо все"
    stop_video
    if is_tv_on; then
        echo "standby 0" | cec-client -s -d 1 > /dev/null 2>&1
        log "🛑 Вимкнули телевізор"
    fi
fi
