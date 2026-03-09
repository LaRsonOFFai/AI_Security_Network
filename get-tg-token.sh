#!/bin/bash
echo "=== Создание Telegram-бота для уведомлений ==="
echo ""
echo "1. Откройте @BotFather в Telegram"
echo "2. Отправьте команду: /newbot"
echo "3. Введите имя бота (например: Server Security Monitor)"
echo "4. Введите username бота (должен заканчиваться на 'bot', например: myserver_security_bot)"
echo "5. Скопируйте полученный TOKEN"
echo ""
echo "6. Теперь узнайте свой Chat ID:"
echo "   - Напишите созданному боту любое сообщение"
echo "   - Откройте в браузере: https://api.telegram.org/bot<ВАШ_TOKEN>/getUpdates"
echo "   - Найдите в ответе 'chat':{'id':123456789}"
echo ""
read -p "Введите TOKEN бота: " BOT_TOKEN
read -p "Введите ваш Chat ID: " CHAT_ID

# Сохраняем конфигурацию
cat > /home/larson/security-monitor/tg_config.conf << CONF
BOT_TOKEN=$BOT_TOKEN
CHAT_ID=$CHAT_ID
CONF

chmod 600 /home/larson/security-monitor/tg_config.conf
echo ""
echo "✅ Конфигурация сохранена!"
echo ""

# Тестовое сообщение
MESSAGE="🛡️ Security Monitor активирован!
📅 $(date '+%Y-%m-%d %H:%M:%S')
🖥️ Сервер: $(hostname)

Теперь вы будете получать уведомления о:
• Множественных неудачных попытках входа
• Блокировках IP через Fail2Ban
• Подозрительной активности
• Изменениях в системе"

curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d "chat_id=${CHAT_ID}" \
  -d "text=${MESSAGE}" > /dev/null

echo "✅ Тестовое сообщение отправлено! Проверьте Telegram."
