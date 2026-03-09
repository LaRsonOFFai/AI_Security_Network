#!/bin/bash
#
# Проверка обучения AI Security System
#

LEARNING_DB="/home/larson/security-monitor/learning_database.dat"
THREAT_DB="/home/larson/security-monitor/threat_database.dat"
LOG_FILE="/home/larson/security-monitor/ai_security.log"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║        ПРОВЕРКА ОБУЧЕНИЯ AI SECURITY SYSTEM              ║"
echo "║        $(date '+%Y-%m-%d %H:%M:%S')                      ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# 1. Проверка базы обучения
echo "━━━ 1. БАЗА ОБУЧЕНИЯ ━━━"
echo ""

if [[ ! -f "$LEARNING_DB" ]]; then
    echo "❌ База обучения не найдена!"
    exit 1
fi

total_entries=$(wc -l < "$LEARNING_DB")
today_entries=$(grep "^$(date '+%Y-%m-%d')" "$LEARNING_DB" | wc -l)

echo "📚 Всего записей: $total_entries"
echo "📚 Записей сегодня: $today_entries"

if [[ $today_entries -gt 0 ]]; then
    echo "✅ Система ОБУЧАЕТСЯ"
else
    echo "⚠️ Система НЕ обучается сегодня"
fi
echo ""

# 2. Статистика действий
echo "━━━ 2. СТАТИСТИКА ДЕЙСТВИЙ ━━━"
echo ""

echo "Распределение по типам действий:"
cat "$LEARNING_DB" | cut -d'|' -f3 | sort | uniq -c | sort -rn | while read count action; do
    percent=$((count * 100 / total_entries))
    case "$action" in
        MONITOR) emoji="👁️" ;;
        TEMP_BAN) emoji="⏱️" ;;
        LONG_BAN) emoji="🔒" ;;
        PERMANENT_BAN) emoji="🚫" ;;
        *) emoji="❓" ;;
    esac
    printf "   %-15s %s %-10s (%d%%)\n" "$action" "$emoji" "$count" "$percent"
done
echo ""

# 3. Эффективность действий
echo "━━━ 3. ЭФФЕКТИВНОСТЬ ━━━"
echo ""

# Считаем успешные действия
success_count=$(grep "|success$" "$LEARNING_DB" | wc -l)
failure_count=$(grep "|failure$" "$LEARNING_DB" | wc -l)

if [[ $total_entries -gt 0 ]]; then
    success_rate=$((success_count * 100 / total_entries))
    echo "✅ Успешных действий: $success_count ($success_rate%)"
    echo "❌ Неудачных действий: $failure_count"
else
    echo "⏳ Нет данных для анализа"
fi
echo ""

# 4. Последние записи
echo "━━━ 4. ПОСЛЕДНИЕ 10 ЗАПИСЕЙ ━━━"
echo ""

tail -10 "$LEARNING_DB" | while IFS='|' read ts ip action result; do
    time=$(echo "$ts" | cut -d' ' -f2)
    case "$action" in
        MONITOR) emoji="👁️" ;;
        TEMP_BAN) emoji="⏱️" ;;
        LONG_BAN) emoji="🔒" ;;
        PERMANENT_BAN) emoji="🚫" ;;
        *) emoji="❓" ;;
    esac
    printf "   [%s] %s %-15s → %s %s\n" "$time" "$emoji" "$ip" "$action" "$result"
done
echo ""

# 5. Топ IP по количеству записей
echo "━━━ 5. ТОП IP (ПО КОЛИЧЕСТВУ ЗАПИСЕЙ) ━━━"
echo ""

cat "$LEARNING_DB" | cut -d'|' -f2 | sort | uniq -c | sort -rn | head -10 | while read count ip; do
    printf "   %-15s → %d записей\n" "$ip" "$count"
done
echo ""

# 6. Активность по времени
echo "━━━ 6. АКТИВНОСТЬ ПО ЧАСАМ (СЕГОДНЯ) ━━━"
echo ""

for hour in $(seq 0 23); do
    hour_padded=$(printf "%02d" $hour)
    count=$(grep "^$(date '+%Y-%m-%d')T${hour_padded}:" "$LEARNING_DB" 2>/dev/null | wc -l)
    if [[ $count -gt 0 ]]; then
        bar=$(printf '%*s' "$((count / 2))" '' | tr ' ' '█')
        printf "   %s:00 → %3d %s\n" "$hour_padded" "$count" "$bar"
    fi
done
echo ""

# 7. Статус процесса
echo "━━━ 7. СТАТУС ПРОЦЕССА ━━━"
echo ""

if pgrep -f "ai_security_v3" > /dev/null; then
    echo "✅ AI Security v3 ЗАПУЩЕН"
    ps aux | grep "ai_security_v3" | grep -v grep | head -3 | while read line; do
        pid=$(echo "$line" | awk '{print $2}')
        cpu=$(echo "$line" | awk '{print $3}')
        mem=$(echo "$line" | awk '{print $4}')
        echo "   PID: $pid, CPU: ${cpu}%, MEM: ${mem}%"
    done
else
    echo "❌ AI Security v3 НЕ запущен"
fi
echo ""

# 8. Проверка логики обучения
echo "━━━ 8. ПРОВЕРКА ЛОГИКИ ОБУЧЕНИЯ ━━━"
echo ""

# Проверяем, записывается ли обучение после разных действий
monitor_count=$(grep "|MONITOR|" "$LEARNING_DB" | wc -l)
ban_count=$(grep -E "\|(TEMP_BAN|LONG_BAN|PERMANENT_BAN)\|" "$LEARNING_DB" | wc -l)

if [[ $monitor_count -gt 0 || $ban_count -gt 0 ]]; then
    echo "✅ Логика обучения РАБОТАЕТ"
    echo "   - Записей MONITOR: $monitor_count"
    echo "   - Записей BAN: $ban_count"
else
    echo "❌ Логика обучения НЕ работает"
fi
echo ""

# 9. Прогноз
echo "━━━ 9. ПРОГНОЗ ━━━"
echo ""

if [[ $today_entries -gt 0 ]]; then
    avg_per_hour=$((today_entries / $(date '+%H') + 1))
    predicted_end=$((avg_per_hour * 24))
    echo "📊 Средняя скорость: ~$avg_per_hour записей/час"
    echo "📊 Прогноз за 24 часа: ~$predicted_end записей"
else
    echo "⏳ Недостаточно данных для прогноза"
fi
echo ""

echo "╔══════════════════════════════════════════════════════════╗"
echo "║                    ПРОВЕРКА ЗАВЕРШЕНА                    ║"
echo "╚══════════════════════════════════════════════════════════╝"
