#!/bin/bash
# Скрипт автоматической установки бота Murino FM на Debian/Ubuntu
# ВНИМАНИЕ: используется токен, который был опубликован. Смените его!

set -e

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
   echo "❌ Этот скрипт должен запускаться с правами root (sudo)."
   exit 1
fi

echo "=== 🎵 Установка бота Murino FM ==="
echo "⚠️ Используется токен: 8989968088:AAHLcf43STmE945zv_M41eqqHGXZNfWlAEs"
echo "⚠️ Этот токен был опубликован. ОБЯЗАТЕЛЬНО смените его после установки!"

# Токен бота (задан жёстко)
BOT_TOKEN="8989968088:AAHLcf43STmE945zv_M41eqqHGXZNfWlAEs"

# --- 1. Обновление системы и установка базовых пакетов ---
echo "📦 Обновление системы и установка базовых пакетов..."
apt update
apt upgrade -y
apt install -y curl wget gnupg2 software-properties-common python3 python3-pip python3-venv screen ufw

# --- 2. Установка Tor (надёжный способ) ---
echo "🔒 Установка Tor..."
if command -v tor &> /dev/null; then
    echo "✅ Tor уже установлен."
else
    if apt-cache show tor &> /dev/null; then
        apt install -y tor
    else
        echo "⚠️ Tor не найден в стандартных репозиториях. Добавляю официальный репозиторий Tor..."
        . /etc/os-release
        if [[ "$ID" == "ubuntu" ]]; then
            REPO="deb [signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $VERSION_CODENAME main"
        elif [[ "$ID" == "debian" ]]; then
            REPO="deb [signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $VERSION_CODENAME main"
        else
            echo "❌ Не удалось определить дистрибутив. Установите Tor вручную."
            exit 1
        fi
        wget -qO- https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --dearmor | tee /usr/share/keyrings/tor-archive-keyring.gpg >/dev/null
        echo "$REPO" | tee /etc/apt/sources.list.d/tor.list
        apt update
        apt install -y tor deb.torproject.org-keyring
    fi
fi

# --- 3. Запуск и включение Tor ---
echo "🔄 Настройка и запуск Tor..."
systemctl start tor
systemctl enable tor
sleep 3

if ss -lnt | grep -q 9050; then
    echo "✅ Tor запущен и слушает порт 9050."
else
    echo "⚠️ Внимание: Tor, возможно, не слушает порт 9050. Проверьте вручную."
fi

if curl --socks5-hostname 127.0.0.1:9050 https://api.telegram.org -s -o /dev/null -w "%{http_code}" | grep -q "200"; then
    echo "✅ Tor работает, подключение к API Telegram успешно."
else
    echo "❌ Не удалось подключиться к Telegram API через Tor. Проверьте настройки сети."
    exit 1
fi

# --- 4. Создание директории бота ---
BOT_DIR="/opt/bot"
mkdir -p "$BOT_DIR"
cd "$BOT_DIR"

# --- 5. Создание requirements.txt ---
cat > requirements.txt <<EOF
aiogram>=3.24.0
aiohttp>=3.14.1
aiohttp-socks>=0.10.1
playwright>=1.40.0
EOF

# --- 6. Создание bot.py с фиксированным токеном ---
cat > bot.py <<EOF
import asyncio
import logging
import subprocess
import sys
import os
from aiogram import Bot, Dispatcher, types, F
from aiogram.types import InlineKeyboardMarkup, InlineKeyboardButton, WebAppInfo
from aiogram.filters import Command
from aiogram.client.session.aiohttp import AiohttpSession
from aiohttp_socks import ProxyConnector
from playwright.async_api import async_playwright

# --- АВТОУСТАНОВКА PLAYWRIGHT И CHROMIUM ---
def auto_install_playwright():
    try:
        import playwright
    except ImportError:
        print("🔄 Устанавливаю библиотеку playwright...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "playwright"])
        print("✅ Playwright установлен.")

    browsers_dir = os.path.expanduser("~/.cache/ms-playwright")
    if not os.path.exists(browsers_dir) or not os.listdir(browsers_dir):
        print("🔄 Устанавливаю браузер chromium (это может занять пару минут)...")
        subprocess.check_call([sys.executable, "-m", "playwright", "install", "chromium"])
        print("✅ Браузер установлен.")
    else:
        print("✅ Браузер уже установлен.")

auto_install_playwright()

# --- КОНФИГУРАЦИЯ ---
# ⚠️ ВНИМАНИЕ: этот токен был опубликован, замените его на новый через @BotFather!
BOT_TOKEN = "$BOT_TOKEN"

# --- НАСТРОЙКА ПРОКСИ (Tor) ---
PROXY_URL = "socks5://127.0.0.1:9050"

connector = ProxyConnector.from_url(PROXY_URL)
session = AiohttpSession(connector=connector)
bot = Bot(token=BOT_TOKEN, session=session)
dp = Dispatcher()

# --- КЛАВИАТУРЫ ---
def get_main_menu():
    keyboard = InlineKeyboardMarkup(inline_keyboard=[
        [
            InlineKeyboardButton(
                text="🎧 Слушать радио",
                web_app=WebAppInfo(url="https://m.volnorez.com/murino_fm")
            )
        ],
        [
            InlineKeyboardButton(
                text="📢 ТГ канал",
                url="https://t.me/myrinskoe_radio"
            )
        ],
        [
            InlineKeyboardButton(
                text="📡 Узнать статус радио",
                callback_data="status"
            )
        ],
        [
            InlineKeyboardButton(
                text="🌐список доменов",
                web_app=WebAppInfo(url="https://taplink.cc/murinofm")
            )
        ],
        [
            InlineKeyboardButton(
                text="📱 Скачать мобильное приложение",
                url="https://www.rustore.ru/catalog/app/ru.murinofm.player"
            )
        ]
    ])
    return keyboard

# --- ОБРАБОТЧИКИ КОМАНД ---
@dp.message(Command("start"))
async def start_command(message: types.Message):
    await message.answer(
        "🎵 Мурино FM BOT\nПриложение Мурино FM в телеграмме",
        reply_markup=get_main_menu()
    )

@dp.message()
async def any_message(message: types.Message):
    await message.answer(
        "🎵 Мурино FM BOT\nПриложение Мурино FM в телеграмме",
        reply_markup=get_main_menu()
    )

# --- ОБРАБОТЧИК СТАТУСА (через Playwright) ---
@dp.callback_query(F.data == "status")
async def status_callback(callback: types.CallbackQuery):
    await callback.answer("Открываем страницу в браузере...")

    result_text = ""
    try:
        async with async_playwright() as p:
            browser = await p.chromium.launch(
                headless=True,
                args=['--disable-gpu', '--no-sandbox', '--disable-dev-shm-usage']
            )
            page = await browser.new_page()
            try:
                await page.goto("https://volnorez.com/murino_fm", wait_until="networkidle")
                await page.wait_for_timeout(3000)
                page_content = await page.content()
                if "Превышено максимальное количество слушателей" in page_content:
                    result_text = "🟡 Превышено максимальное количество слушателей."
                elif "В данный момент радиостанция отключена" in page_content:
                    result_text = "🔴 Радио не запущено в этот момент."
                else:
                    result_text = "🟢 Радио запущено в этот момент!"
            except Exception as e:
                result_text = f"❌ Ошибка при загрузке страницы: {str(e)}"
            finally:
                await browser.close()
    except Exception as e:
        result_text = f"❌ Ошибка запуска браузера: {str(e)}"

    await callback.message.answer(result_text)
    await callback.answer()

# --- ЗАПУСК ---
async def main():
    logging.basicConfig(level=logging.INFO)
    print("Бот запущен. Telegram API подключён через Tor, статус радио проверяется напрямую через Playwright Chromium.")
    await dp.start_polling(bot)

if __name__ == "__main__":
    asyncio.run(main())
EOF

# --- 7. Виртуальное окружение и установка зависимостей ---
echo "🐍 Создание виртуального окружения и установка зависимостей..."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# --- 8. systemd сервис ---
SERVICE_FILE="/etc/systemd/system/bot.service"
cat > $SERVICE_FILE <<EOF
[Unit]
Description=Murino FM Telegram Bot
After=network.target tor.service

[Service]
User=root
WorkingDirectory=$BOT_DIR
ExecStart=$BOT_DIR/venv/bin/python $BOT_DIR/bot.py
Restart=always
RestartSec=10
Environment="PYTHONUNBUFFERED=1"

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable bot
systemctl start bot

# --- 9. Удаление вебхука ---
echo "🧹 Удаление вебхука (если он был)..."
curl -X POST "https://api.telegram.org/bot$BOT_TOKEN/deleteWebhook"

# --- 10. Добавление swap (если отсутствует) ---
SWAPFILE="/swapfile"
if [[ ! -f "$SWAPFILE" ]]; then
    echo "💾 Создание файла подкачки 1 ГБ..."
    fallocate -l 1G $SWAPFILE
    chmod 600 $SWAPFILE
    mkswap $SWAPFILE
    swapon $SWAPFILE
    echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
else
    echo "✅ Swap уже существует."
fi

# --- 11. Итог ---
echo "====================================================="
echo "✅ Бот успешно установлен и запущен!"
echo "Статус бота:"
systemctl status bot --no-pager
echo ""
echo "📋 Для просмотра логов: journalctl -u bot -f"
echo "🔄 Для перезапуска: systemctl restart bot"
echo "📁 Файлы бота находятся в $BOT_DIR"
echo "====================================================="
echo "⚠️ НЕ ЗАБУДЬТЕ СМЕНИТЬ ТОКЕН через @BotFather!"