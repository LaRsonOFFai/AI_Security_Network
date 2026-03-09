#!/bin/bash
#
# Быстрая проверка заблокированных IP за сегодня
#

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
THREAT_DB="${SCRIPT_DIR}/threat_database.dat"
LEARNING_DB="${SCRIPT_DIR}/learning_database.dat"

TODAY=$(date '+%Y-%m-%d')

echo "╔══════════════════════════════════════════════════════╗"
echo "║  БЛОКИРОВКИ ЗА СЕГОДНЯ  $(date '+%H:%M')             ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

if [[ ! -f "$THREAT_DB" ]]; then
    echo "❌ База угроз не найдена!"
    exit 1
fi

# Только заблокированные (не MONITOR)
echo "🚫 **ПОСТОЯННЫЕ БЛОКИРОВКИ (LONG_BAN/PERMANENT_BAN):**"
grep "^$TODAY" "$THREAT_DB" | grep -E "\|(LONG_BAN|PERMANENT_BAN)" | cut -d'|' -f2 | sort -u | while read ip; do
    count=$(grep "^$TODAY" "$THREAT_DB" | grep "$ip" | wc -l)
    last_time=$(grep "^$TODAY" "$THREAT_DB" | grep "$ip" | tail -1 | cut -d'|' -f1 | cut -d' ' -f2)
    last_type=$(grep "^$TODAY" "$THREAT_DB" | grep "$ip" | tail -1 | cut -d'|' -f5)
    echo "   🔴 $ip"
    echo "      └─ Атак: $count | Последняя: $last_time | Тип: $last_type"
done

echo ""
echo "⏱️ **ВРЕМЕННЫЕ БЛОКИРОВКИ (TEMP_BAN):**"
grep "^$TODAY" "$THREAT_DB" | grep "TEMP_BAN" | cut -d'|' -f2 | sort -u | while read ip; do
    count=$(grep "^$TODAY" "$THREAT_DB" | grep "$ip" | grep "TEMP_BAN" | wc -l)
    last_time=$(grep "^$TODAY" "$THREAT_DB" | grep "$ip" | tail -1 | cut -d'|' -f1 | cut -d' ' -f2)
    echo "   🟠 $ip (атак: $count, последняя: $last_time)"
done

echo ""
echo "📊 **СТАТИСТИКА:**"
total=$(grep "^$TODAY" "$THREAT_DB" | wc -l)
blocked=$(grep "^$TODAY" "$THREAT_DB" | grep -E "\|(LONG_BAN|PERMANENT_BAN|TEMP_BAN)" | wc -l)
monitored=$(grep "^$TODAY" "$THREAT_DB" | grep "MONITOR" | wc -l)

echo "   Всего событий: $total"
echo "   Заблокировано: $blocked"
echo "   Под наблюдением: $monitored"

echo ""
echo "📚 **ОБУЧЕНИЕ:**"
if [[ -f "$LEARNING_DB" ]]; then
    learn_count=$(grep "^$TODAY" "$LEARNING_DB" | wc -l)
    if [[ $learn_count -gt 0 ]]; then
        echo "   ✅ Записей сегодня: $learn_count"
        echo "   Последние:"
        tail -3 "$LEARNING_DB" | while IFS='|' read ts ip action result; do
            echo "      • $ip → $action ($result)"
        done
    else
        echo "   ⏳ Ожидание данных..."
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 Для полного отчёта: ~/security-monitor/check-today.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
