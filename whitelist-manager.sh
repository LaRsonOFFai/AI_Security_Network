#!/bin/bash
#
# Whitelist Manager для AI Security System
# Анализирует успешные подключения и управляет белым списком
#

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CONFIG_FILE="${SCRIPT_DIR}/ai_config.conf"
WHITELIST_FILE="${SCRIPT_DIR}/whitelist.txt"
WHITELIST_LEARN="${SCRIPT_DIR}/whitelist_learning.dat"
AUTH_LOG="/var/log/auth.log"

# Загрузка конфига
source "$CONFIG_FILE"

# === АНАЛИЗ УСПЕШНЫХ ПОДКЛЮЧЕНИЙ ===
analyze_successful_connections() {
    echo "━━━ АНАЛИЗ УСПЕШНЫХ ПОДКЛЮЧЕНИЙ ━━━"
    echo ""
    
    # Получаем успешные подключения за последние 24 часа
    local successful
    successful=$(sudo grep "Accepted" "$AUTH_LOG" 2>/dev/null | \
        awk '{for(i=1;i<=NF;i++) if($i=="from") print $(i+1)}' | \
        sort | uniq -c | sort -rn)
    
    if [[ -z "$successful" ]]; then
        echo "⚠️ Нет данных об успешных подключениях"
        return
    fi
    
    echo "Успешные подключения:"
    echo "$successful" | head -20 | while read count ip; do
        if [[ $count -ge ${WHITELIST_MIN_CONNECTIONS:-5} ]]; then
            echo "   ✅ $ip → $count подключений"
        else
            echo "   👁️ $ip → $count подключений (ещё не в whitelist)"
        fi
    done
    echo ""
}

# === ДОБАВЛЕНИЕ В WHITELIST ===
add_to_whitelist() {
    local ip="$1"
    local reason="$2"
    
    # Проверяем, есть ли уже в whitelist
    if grep -q "^$ip" "$WHITELIST_FILE" 2>/dev/null; then
        echo "   ⚠️ $ip уже в whitelist"
        return
    fi
    
    # Добавляем
    echo "$ip # $(date '+%Y-%m-%d %H:%M:%S') $reason" >> "$WHITELIST_FILE"
    echo "   ✅ $ip добавлен в whitelist"
    
    # Записываем в лог обучения
    echo "$(date '+%Y-%m-%d %H:%M:%S')|$ip|ADDED|$reason" >> "$WHITELIST_LEARN"
}

# === АВТОМАТИЧЕСКОЕ ЗАПОЛНЕНИЕ WHITELIST ===
auto_populate_whitelist() {
    echo "━━━ АВТОМАТИЧЕСКОЕ ЗАПОЛНЕНИЕ WHITELIST ━━━"
    echo ""
    
    # Получаем успешные подключения
    local successful
    successful=$(sudo grep "Accepted" "$AUTH_LOG" 2>/dev/null | \
        tail -1000 | awk '{for(i=1;i<=NF;i++) if($i=="from") print $(i+1)}' | \
        sort | uniq -c | sort -rn)
    
    local added=0
    
    while read count ip; do
        if [[ -z "$ip" ]]; then
            continue
        fi
        
        # Проверяем порог
        if [[ $count -ge ${WHITELIST_MIN_CONNECTIONS:-5} ]]; then
            # Проверяем, есть ли в whitelist
            if ! grep -q "^$ip" "$WHITELIST_FILE" 2>/dev/null; then
                # Проверяем лимит
                local current_count
                current_count=$(wc -l < "$WHITELIST_FILE" 2>/dev/null || echo 0)
                
                if [[ $current_count -lt ${MAX_WHITELIST_ENTRIES:-500} ]]; then
                    add_to_whitelist "$ip" "Auto: $count successful connections"
                    added=$((added + 1))
                else
                    echo "⚠️ Достигнут лимит whitelist (${MAX_WHITELIST_ENTRIES})"
                    break
                fi
            fi
        fi
    done <<< "$successful"
    
    echo ""
    echo "Добавлено IP в whitelist: $added"
    echo ""
}

# === ПРОВЕРКА IP В WHITELIST ===
check_ip_in_whitelist() {
    local ip="$1"
    
    if [[ -f "$WHITELIST_FILE" ]]; then
        if grep -q "^$ip" "$WHITELIST_FILE"; then
            return 0
        fi
    fi
    return 1
}

# === УДАЛЕНИЕ ИЗ WHITELIST ===
remove_from_whitelist() {
    local ip="$1"
    
    if [[ -f "$WHITELIST_FILE" ]]; then
        grep -v "^$ip" "$WHITELIST_FILE" > "${WHITELIST_FILE}.tmp"
        mv "${WHITELIST_FILE}.tmp" "$WHITELIST_FILE"
        echo "✅ $ip удалён из whitelist"
    else
        echo "⚠️ Whitelist не существует"
    fi
}

# === ПОКАЗАТЬ WHITELIST ===
show_whitelist() {
    echo "━━━ БЕЛЫЙ СПИСОК ━━━"
    echo ""
    
    if [[ ! -f "$WHITELIST_FILE" ]]; then
        echo "⚠️ Whitelist пуст"
        return
    fi
    
    local count
    count=$(wc -l < "$WHITELIST_FILE")
    echo "Записей в whitelist: $count"
    echo ""
    
    echo "IP адреса:"
    cat "$WHITELIST_FILE" | while read line; do
        ip=$(echo "$line" | cut -d'#' -f1 | tr -d ' ')
        reason=$(echo "$line" | cut -d'#' -f2-)
        echo "   ✅ $ip $reason"
    done
    echo ""
}

# === СТАТИСТИКА ===
show_whitelist_stats() {
    echo "━━━ СТАТИСТИКА WHITELIST ━━━"
    echo ""
    
    if [[ ! -f "$WHITELIST_FILE" ]]; then
        echo "⚠️ Whitelist не существует"
        return
    fi
    
    local total
    total=$(wc -l < "$WHITELIST_FILE")
    echo "Всего записей: $total"
    
    if [[ -f "$WHITELIST_LEARN" ]]; then
        local auto_added
        auto_added=$(grep "|ADDED|Auto:" "$WHITELIST_LEARN" | wc -l)
        echo "Добавлено автоматически: $auto_added"
        
        local manual_added
        manual_added=$(grep "|ADDED|Manual:" "$WHITELIST_LEARN" | wc -l)
        echo "Добавлено вручную: $manual_added"
    fi
    echo ""
}

# === ГЛАВНОЕ МЕНЮ ===
echo "╔══════════════════════════════════════════════════════════╗"
echo "║         AI SECURITY - WHITELIST MANAGER                  ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Создаём файлы если нет
touch "$WHITELIST_FILE" "$WHITELIST_LEARN"

echo "1. Проанализировать успешные подключения"
echo "2. Автоматически заполнить whitelist"
echo "3. Показать whitelist"
echo "4. Добавить IP вручную"
echo "5. Удалить IP из whitelist"
echo "6. Статистика"
echo "7. Выход"
echo ""

read -p "Выберите действие (1-7): " choice

case $choice in
    1)
        analyze_successful_connections
        ;;
    
    2)
        auto_populate_whitelist
        ;;
    
    3)
        show_whitelist
        ;;
    
    4)
        read -p "Введите IP адрес: " ip
        read -p "Причина добавления: " reason
        add_to_whitelist "$ip" "Manual: $reason"
        ;;
    
    5)
        read -p "Введите IP адрес для удаления: " ip
        remove_from_whitelist "$ip"
        ;;
    
    6)
        show_whitelist_stats
        ;;
    
    7)
        echo "Выход"
        exit 0
        ;;
    
    *)
        echo "❌ Неверный выбор"
        exit 1
        ;;
esac

echo "╔══════════════════════════════════════════════════════════╗"
echo "║                    ГОТОВО!                               ║"
echo "╚══════════════════════════════════════════════════════════╝"
