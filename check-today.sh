#!/bin/bash
#
# Проверка активности системы защиты за сегодня
#

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
THREAT_DB="${SCRIPT_DIR}/threat_database.dat"
LEARNING_DB="${SCRIPT_DIR}/learning_database.dat"
LOG_FILE="${SCRIPT_DIR}/ai_security.log"
CONFIG_FILE="${SCRIPT_DIR}/tg_config.conf"

TODAY=$(date '+%Y-%m-%d')

echo "╔══════════════════════════════════════════════════════════╗"
echo "║     AI SECURITY SYSTEM - ОТЧЁТ ЗА СЕГОДНЯ                ║"
echo "║     $(date '+%Y-%m-%d %H:%M:%S')                          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Загрузка TG конфига
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    echo "📱 Telegram бот: ${BOT_TOKEN:0:20}..."
    echo "👤 Chat ID: $CHAT_ID"
else
    echo "❌ TG конфиг не найден!"
fi
echo ""

# === 1. СТАТИСТИКА ЗА СЕГОДНЯ ===
echo "━━━ 1. СТАТИСТИКА БЛОКИРОВОК ━━━"

if [[ -f "$THREAT_DB" ]]; then
    total_today=$(grep "^$TODAY" "$THREAT_DB" | wc -l)
    echo "📊 Всего событий сегодня: $total_today"
    echo ""
    
    # По уровням угроз
    echo "📈 По уровням угроз:"
    critical=$(grep "^$TODAY" "$THREAT_DB" | cut -d'|' -f3 | grep -c "^4$" || echo 0)
    high=$(grep "^$TODAY" "$THREAT_DB" | cut -d'|' -f3 | grep -c "^3$" || echo 0)
    medium=$(grep "^$TODAY" "$THREAT_DB" | cut -d'|' -f3 | grep -c "^2$" || echo 0)
    low=$(grep "^$TODAY" "$THREAT_DB" | cut -d'|' -f3 | grep -c "^1$" || echo 0)
    
    echo "   🚨 CRITICAL: $critical"
    echo "   🔴 HIGH:     $high"
    echo "   🟠 MEDIUM:   $medium"
    echo "   🟡 LOW:      $low"
    echo ""
    
    # Заблокированные IP (LONG_BAN и PERMANENT_BAN)
    echo "🚫 Заблокированные IP (LONG_BAN/PERMANENT_BAN):"
    grep "^$TODAY" "$THREAT_DB" | grep -E "\|(LONG_BAN|PERMANENT_BAN)" | cut -d'|' -f2 | sort -u | while read ip; do
        count=$(grep "^$TODAY" "$THREAT_DB" | grep "$ip" | wc -l)
        last_type=$(grep "^$TODAY" "$THREAT_DB" | grep "$ip" | tail -1 | cut -d'|' -f5)
        echo "   • $ip (атак: $count, тип: $last_type)"
    done
    echo ""
    
    # Временно заблокированные
    temp_banned=$(grep "^$TODAY" "$THREAT_DB" | grep -c "TEMP_BAN" || echo 0)
    echo "⏱️ Временно заблокировано (TEMP_BAN): $temp_banned"
    echo ""
    
    # Топ атакующих
    echo "🎯 Топ атакующих IP:"
    grep "^$TODAY" "$THREAT_DB" | cut -d'|' -f2 | sort | uniq -c | sort -rn | head -10 | while read count ip; do
        echo "   $ip - $count атак"
    done
else
    echo "❌ База угроз не найдена!"
fi
echo ""

# === 2. ОБУЧЕНИЕ ===
echo "━━━ 2. ОБУЧЕНИЕ СИСТЕМЫ ━━━"

if [[ -f "$LEARNING_DB" ]]; then
    total_learn=$(wc -l < "$LEARNING_DB")
    today_learn=$(grep "^$TODAY" "$LEARNING_DB" | wc -l)
    echo "📚 Записей в базе обучения: $total_learn"
    echo "📚 Записей сегодня: $today_learn"
    
    if [[ $today_learn -gt 0 ]]; then
        echo "✅ Система ОБУЧАЕТСЯ"
        echo ""
        echo "Последние записи:"
        tail -5 "$LEARNING_DB" | while IFS='|' read ts ip action result; do
            echo "   $ts | $ip | $action | $result"
        done
    else
        echo "⚠️ Система НЕ обучается сегодня"
    fi
else
    echo "❌ База обучения не найдена!"
fi
echo ""

# === 3. ТЕЛЕГРАМ УВЕДОМЛЕНИЯ ===
echo "━━━ 3. TELEgram УВЕДОМЛЕНИЯ ━━━"

if [[ -f "$LOG_FILE" ]]; then
    tg_total=$(grep "TG:" "$LOG_FILE" | wc -l)
    tg_today=$(grep "^.\[$TODAY" "$LOG_FILE" | grep "TG:" | wc -l)
    
    echo "📤 Всего отправлено TG сообщений: $tg_total"
    echo "📤 Отправлено сегодня: $tg_today"
    echo ""
    
    echo "Последние TG уведомления:"
    grep "TG:" "$LOG_FILE" | tail -10 | while read line; do
        time=$(echo "$line" | grep -oP '\[\K[0-9-]+ [0-9:]+')
        msg=$(echo "$line" | sed 's/.*TG: //' | head -c 60)
        echo "   [$time] $msg..."
    done
else
    echo "❌ Лог файл не найден!"
fi
echo ""

# === 4. ТЕКУЩИЕ БЛОКИРОВКИ IPTABLES ===
echo "━━━ 4. АКТИВНЫЕ ПРАВИЛА IPTABLES (AI) ━━━"

ai_rules=$(sudo iptables -L INPUT -n 2>/dev/null | grep -c "AI_" || echo 0)
echo "🛡️ Правил AI в iptables: $ai_rules"

if [[ $ai_rules -gt 0 ]]; then
    echo ""
    echo "Первые 10 правил:"
    sudo iptables -L INPUT -n 2>/dev/null | grep "AI_" | head -10 | while read line; do
        src=$(echo "$line" | awk '{print $4}')
        echo "   • $src"
    done
fi
echo ""

# === 5. СТАТУС ПРОЦЕССОВ ===
echo "━━━ 5. СТАТУС ПРОЦЕССОВ ━━━"

if pgrep -f "ai_security" > /dev/null; then
    echo "✅ AI Security запущен"
    ps aux | grep "ai_security" | grep -v grep | awk '{print "   PID: "$2", CPU: "$3"%, MEM: "$4"%"}'
else
    echo "❌ AI Security НЕ запущен"
fi
echo ""

# === 6. ТЕСТ УВЕДОМЛЕНИЯ ===
echo "━━━ 6. ТЕСТ УВЕДОМЛЕНИЯ ━━━"
echo "Отправка тестового сообщения..."

if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
    response=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        -d "text=🧪 <b>ТЕСТ УВЕДОМЛЕНИЯ</b>

📅 Время: $(date '+%Y-%m-%d %H:%M:%S')
✅ Бот работает
✅ Связь есть

Это тестовое сообщение от AI Security System" \
        -d "parse_mode=HTML")
    
    if echo "$response" | grep -q '"ok":true'; then
        echo "✅ Тестовое сообщение ОТПРАВЛЕНО"
        echo "Проверьте Telegram!"
    else
        echo "❌ Ошибка отправки:"
        echo "$response"
    fi
else
    echo "❌ BOT_TOKEN или CHAT_ID не настроены"
fi
echo ""

echo "╔══════════════════════════════════════════════════════════╗"
echo "║                    КОНЕЦ ОТЧЁТА                          ║"
echo "╚══════════════════════════════════════════════════════════╝"
