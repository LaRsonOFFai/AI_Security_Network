#!/bin/bash
#
# Установка AI Security System
#

set -e

echo "🧠 Установка AI Security System..."
echo ""

SCRIPT_DIR="/home/larson/security-monitor"

# 1. Проверяем существование скриптов
if [[ ! -f "$SCRIPT_DIR/ai_security.sh" ]]; then
    echo "❌ ai_security.sh не найден!"
    exit 1
fi

# 2. Создаём необходимые файлы
touch "$SCRIPT_DIR/threat_database.dat"
touch "$SCRIPT_DIR/learning_database.dat"
touch "$SCRIPT_DIR/blacklist_permanent.txt"
touch "$SCRIPT_DIR/ai_state.dat"

# 3. Делаем скрипты исполняемыми
chmod +x "$SCRIPT_DIR"/*.sh

# 4. Защищаем конфигурацию
chmod 600 "$SCRIPT_DIR/ai_config.conf"
chmod 600 "$SCRIPT_DIR/tg_config.conf" 2>/dev/null || true

# 5. Создаём systemd службу
echo '[Unit]
Description=AI Security System
After=network.target fail2ban.service
Wants=fail2ban.service

[Service]
Type=simple
User=root
WorkingDirectory=/home/larson/security-monitor
ExecStart=/bin/bash /home/larson/security-monitor/ai_security.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ai-security

[Install]
WantedBy=multi-user.target' | sudo tee /etc/systemd/system/ai-security.service > /dev/null

# 6. Перезагружаем systemd
sudo systemctl daemon-reload

# 7. Включаем службу
sudo systemctl enable ai-security.service

# 8. Запускаем службу
sudo systemctl start ai-security.service

# 9. Проверяем статус
echo ""
echo "=== Статус службы ==="
sudo systemctl status ai-security.service --no-pager

echo ""
echo "=== Последние логи ==="
sudo journalctl -u ai-security.service --no-pager -n 20

echo ""
echo "✅ AI Security System установлена и запущена!"
echo ""
echo "📊 Мониторинг:"
echo "  sudo systemctl status ai-security       # Статус"
echo "  sudo journalctl -u ai-security -f       # Логи в реальном времени"
echo "  sudo tail -f $SCRIPT_DIR/ai_security.log  # Лог ИИ"
echo ""
echo "📁 Файлы:"
echo "  $SCRIPT_DIR/threat_database.dat    # База угроз"
echo "  $SCRIPT_DIR/learning_database.dat  # База обучения"
echo "  $SCRIPT_DIR/blacklist_permanent.txt # Чёрный список"
echo ""
