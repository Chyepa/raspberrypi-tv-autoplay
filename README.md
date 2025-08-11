# raspberrypi-tv-autoplay
A resilient Raspberry Pi digital signage system with auto video download (Google Drive/URL), looped playback via VLC, HDMI-CEC TV control, fallback video when offline, read-only root to survive power loss, Wi-Fi auto-recovery, and RAM-based logs — built for 24/7 autonomous operation.

UA
#Структура
├── play_video.sh            # Скрипт завантаження та відтворення відео
├── tv_cron.sh               # Основна логіка перевірки інтернету, ТВ і запуску відео
├── fallback.mp4             # ваше резервне відео
├── tvcontrol.service        # systemd сервіс
├── README.md                # Документація


# Raspberry Pi TV Autoplay

Автономна система для Raspberry Pi, яка:
- Завантажує відео з Google Drive або прямого URL
- Відтворює його в циклі на телевізорі
- Керує телевізором через HDMI-CEC
- Має fallback-відео на випадок відсутності інтернету
- Працює у режимі read-only root для захисту від збоїв живлення

## Можливості
- Автоматичне ввімкнення/вимкнення ТВ
- Автовідновлення після втрати інтернету
- Захист SD-карти
- Логи в RAM
Також можете доробити скрипт, якщо немає інтернету, щоб відео відтворювалось завжди поки не появиться інтернет

ENG
#Structure
├── play_video.sh # Script to load and play video
├── tv_cron.sh # Basic logic for checking the Internet, TV and starting the video
├── fallback.mp4 # your backup video
├── tvcontrol.service # systemd service
├── README.md # Documentation

# Raspberry Pi TV Autoplay

A standalone system for Raspberry Pi that:
- Loads video from Google Drive or a direct URL
- Plays it in a loop on the TV
- Controls the TV via HDMI-CEC
- Has a fallback video in case of no Internet
- Works in read-only root mode to protect against power failures

## Features
- Automatic TV on/off
- Auto-recovery after losing the Internet
- SD card protection
- Logs in RAM
You can also modify the script if there is no Internet so that the video always plays until the Internet appears
