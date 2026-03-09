#!/bin/bash
#
# Установка Security Monitor
#

set -e

echo "🛡️ Установка Security Monitor..."
echo ""

SCRIPT_DIR="/home/larson/security-monitor"

# 1. Создаём директорию
mkdir -p "$SCRIPT_DIR"

# 2. Делаем скрипты исполняемыми
chmod +x "$SCRIPT_DIR"/*.sh

# 3. Настраиваем права
chmod 600 "$SCRIPT_DIR/tg_config.conf" 2>/dev/null || true

# 4. Перезагружаем systemd
sudo systemctl daemon-reload

# 5. Включаем службу
sudo systemctl enable security-monitor.service

# 6. Запускаем службу
sudo systemctl start security-monitor.service

# 7. Проверяем статус
echo ""
echo "=== Статус службы ==="
sudo systemctl status security-monitor.service --no-pager

echo ""
echo "=== Логи ==="
sudo journalctl -u security-monitor.service --no-pager -n 20

echo ""
echo "✅ Установка завершена!"
echo ""
echo "Полезные команды:"
echo "  sudo systemctl status security-monitor  # Статус"
echo "  sudo systemctl restart security-monitor # Перезапуск"
echo "  sudo journalctl -u security-monitor -f  # Логи в реальном времени"
echo ""
