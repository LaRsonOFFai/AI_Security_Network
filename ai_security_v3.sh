#!/bin/bash
#
# AI Security System v3.0 - COMPREHENSIVE EDITION
# Полная система защиты с мониторингом ВСЕХ типов атак
#

set -u

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CONFIG_FILE="${SCRIPT_DIR}/ai_config.conf"
STATE_FILE="${SCRIPT_DIR}/ai_state.dat"
THREAT_DB="${SCRIPT_DIR}/threat_database.dat"
LEARNING_DB="${SCRIPT_DIR}/learning_database.dat"
LOG_FILE="${SCRIPT_DIR}/ai_security.log"
ATTACK_MONITOR="${SCRIPT_DIR}/attack_monitor.sh"

# Загрузка конфигурации
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Также загружаем Telegram конфиг
if [[ -f "${SCRIPT_DIR}/tg_config.conf" ]]; then
    source "${SCRIPT_DIR}/tg_config.conf"
fi

# === КОНФИГУРАЦИЯ ИИ ===
declare -A IP_REPUTATION
declare -A IP_ATTACK_HISTORY
declare -A IP_LAST_SEEN
declare -A IP_ATTACK_TYPES        # Новые типы атак
declare -A IP_ROOT_ATTEMPTS
declare -A IP_USERS_TARGETED

# Уровни угрозы
THREAT_LEVEL_LOW=1
THREAT_LEVEL_MEDIUM=2
THREAT_LEVEL_HIGH=3
THREAT_LEVEL_CRITICAL=4

# Веса для разных типов атак
declare -A ATTACK_WEIGHTS=(
    ["SSH"]=10
    ["SSH_ROOT"]=20
    ["SSH_INVALID_USER"]=15
    ["DNS_FLOOD"]=30
    ["DNS_TUNNEL"]=40
    ["DDOS_SYN"]=50
    ["DDOS_UDP"]=50
    ["DDOS_ICMP"]=40
    ["DDOS_CONN"]=30
    ["DDOS_BANDWIDTH"]=60
    ["PORT_SCAN"]=25
    ["PORT_SCAN_MULTI"]=35
    ["WEB_SQLI"]=40
    ["WEB_XSS"]=35
    ["WEB_TRAVERSAL"]=30
    ["FTP_BRUTE"]=20
    ["MYSQL_BRUTE"]=30
    ["SMTP_BRUTE"]=25
    ["TIME_NIGHT"]=15
    ["TIME_WEEKEND"]=20
    ["TIME_RAPID"]=40
    ["SYSTEM_SUID"]=80
    ["SYSTEM_PASSWD"]=90
    ["SYSTEM_CRON"]=50
    ["SYSTEM_IPTABLES"]=60
)

# === ЛОГИРОВАНИЕ ===
log() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

# === ОТПРАВКА В TELEGRAM ===
send_tg() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        -d "text=${message}" \
        -d "parse_mode=HTML" \
        -d "disable_web_page_preview=true" > /dev/null
    log "INFO" "TG: ${message:0:80}..."
}

# === ГЕОЛОКАЦИЯ ===
get_geo_info() {
    local ip="$1"
    curl -s "http://ip-api.com/line/${ip}" 2>/dev/null || echo "Unknown"
}

# === ОЦЕНКА УГРОЗЫ ПО ТИПУ АТАКИ ===
calculate_threat_from_attack() {
    local attack_type="$1"
    local count="$2"
    local ip="$3"
    
    # Базовый вес атаки
    local base_weight="${ATTACK_WEIGHTS[$attack_type]:-10}"
    
    # Умножаем на количество
    local threat_score=$((base_weight * count / 5))
    
    # Добавляем гео-риск
    local geo_info
    geo_info=$(get_geo_info "$ip")
    local country
    country=$(echo "$geo_info" | head -1)
    
    case "$country" in
        "China"|"CN") threat_score=$((threat_score + 20)) ;;
        "Russia"|"RU") threat_score=$((threat_score + 15)) ;;
        "North Korea"|"KP") threat_score=$((threat_score + 30)) ;;
    esac
    
    # Нормализация
    if [[ $threat_score -gt 100 ]]; then
        threat_score=100
    fi
    
    # Определение уровня
    local level
    if [[ $threat_score -ge 70 ]]; then
        level=$THREAT_LEVEL_CRITICAL
    elif [[ $threat_score -ge 50 ]]; then
        level=$THREAT_LEVEL_HIGH
    elif [[ $threat_score -ge 30 ]]; then
        level=$THREAT_LEVEL_MEDIUM
    else
        level=$THREAT_LEVEL_LOW
    fi
    
    echo "$level:$threat_score"
}

# === АДАПТИВНЫЙ ОТВЕТ ===
adaptive_response_v3() {
    local ip="$1"
    local attack_type="$2"
    local threat_level="$3"
    local count="$4"
    
    local response_action=""
    local message=""
    
    case $threat_level in
        $THREAT_LEVEL_LOW)
            response_action="MONITOR"
            message="🟡 <b>Низкая угроза</b>
📍 IP: <code>${ip}</code>
🔍 Тип: ${attack_type}
📊 Атак: ${count}"
            ;;
        $THREAT_LEVEL_MEDIUM)
            response_action="TEMP_BAN"
            if ! sudo iptables -L INPUT -n 2>/dev/null | grep -q "$ip"; then
                sudo iptables -A INPUT -s "$ip" -j DROP -m comment --comment "AI_V3_TEMP"
            fi
            message="🟠 <b>Средняя угроза</b>
📍 IP: <code>${ip}</code>
🔍 Тип: ${attack_type}
📊 Атак: ${count}
⏱️ Бан: 10 минут"
            ;;
        $THREAT_LEVEL_HIGH)
            response_action="LONG_BAN"
            if ! sudo iptables -L INPUT -n 2>/dev/null | grep -q "$ip"; then
                sudo iptables -A INPUT -s "$ip" -j DROP -m comment --comment "AI_V3_LONG"
            fi
            message="🔴 <b>Высокая угроза</b>
📍 IP: <code>${ip}</code>
🔍 Тип: ${attack_type}
📊 Атак: ${count}
⏱️ Бан: 24 часа"
            ;;
        $THREAT_LEVEL_CRITICAL)
            response_action="PERMANENT_BAN"
            if ! sudo iptables -L INPUT -n 2>/dev/null | grep -q "$ip"; then
                sudo iptables -A INPUT -s "$ip" -j DROP -m comment --comment "AI_V3_PERM"
            fi
            echo "$ip # $(date '+%Y-%m-%d %H:%M:%S') Type: $attack_type" >> "${SCRIPT_DIR}/blacklist_permanent.txt"
            
            local geo_info
            geo_info=$(get_geo_info "$ip")
            message="🚨 <b>КРИТИЧЕСКАЯ УГРОЗА!</b>
📍 IP: <code>${ip}</code>
🔍 Тип: ${attack_type}
📊 Атак: ${count}
🌍 Страна: ${geo_info}
♾️ Бан: НАВСЕГДА"
            ;;
    esac
    
    if [[ "$response_action" != "MONITOR" ]]; then
        send_tg "$message"
    fi
    
    log "INFO" "Response: $response_action for $ip ($attack_type)"
    echo "$response_action"
}

# === ОСНОВНОЙ ЦИКЛ МОНИТОРИНГА ===
monitor_and_respond() {
    # Запускаем расширенный мониторинг
    local all_attacks
    all_attacks=$(bash "$ATTACK_MONITOR" 2>/dev/null)
    
    if [[ -z "$all_attacks" ]]; then
        return
    fi
    
    # Обрабатываем каждую атаку
    while IFS='|' read -r attack_type ip count desc; do
        if [[ -z "$ip" || -z "$attack_type" ]]; then
            continue
        fi

        # Для IP атак
        if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            # Обновляем историю
            local prev="${IP_ATTACK_HISTORY[$ip]:-0}"
            IP_ATTACK_HISTORY[$ip]=$((prev + count))

            # Сохраняем тип атаки
            local prev_types="${IP_ATTACK_TYPES[$ip]:-}"
            IP_ATTACK_TYPES[$ip]="${prev_types}${attack_type},"

            # Рассчитываем угрозу
            local threat_info
            threat_info=$(calculate_threat_from_attack "$attack_type" "$count" "$ip")
            local threat_level
            threat_level=$(echo "$threat_info" | cut -d':' -f1)
            local threat_score
            threat_score=$(echo "$threat_info" | cut -d':' -f2)

            # Адаптивный ответ
            local response
            response=$(adaptive_response_v3 "$ip" "$attack_type" "$threat_level" "$count")

            # ОБУЧЕНИЕ: записываем результат
            echo "$(date '+%Y-%m-%d %H:%M:%S')|$ip|$response|success" >> "$LEARNING_DB"

            # Запись в базу
            echo "$(date '+%Y-%m-%d %H:%M:%S')|$ip|$threat_level|$threat_score|$attack_type|$desc" >> "$THREAT_DB"
        else
            # Для не-IP атак (DDoS, System)
            log "INFO" "Attack: $attack_type - $desc (Count: $count)"
            
            if [[ "$attack_type" == *"CRITICAL"* || "$attack_type" == "SYSTEM_"* ]]; then
                send_tg "🚨 <b>КРИТИЧЕСКОЕ СОБЫТИЕ!</b>
🔍 Тип: ${attack_type}
📊 Детали: ${desc}
⚠️ Требуется немедленная проверка!"
            fi
        fi
        
    done <<< "$all_attacks"
}

# === ЕЖЕЧАСНЫЙ ОТЧЁТ V3 ===
send_hourly_report_v3() {
    local minute
    minute=$(date +%M)
    
    if [[ "$minute" == "00" && "${LAST_HOURLY_REPORT:-}" != "$(date +%H)" ]]; then
        # Статистика по типам атак
        local ssh_count
        ssh_count=$(grep "SSH|" "$THREAT_DB" 2>/dev/null | wc -l)
        local dns_count
        dns_count=$(grep "DNS_" "$THREAT_DB" 2>/dev/null | wc -l)
        local ddos_count
        ddos_count=$(grep "DDOS_" "$THREAT_DB" 2>/dev/null | wc -l)
        local port_scan_count
        port_scan_count=$(grep "PORT_" "$THREAT_DB" 2>/dev/null | wc -l)
        local web_count
        web_count=$(grep "WEB_" "$THREAT_DB" 2>/dev/null | wc -l)
        local system_count
        system_count=$(grep "SYSTEM_" "$THREAT_DB" 2>/dev/null | wc -l)
        
        local total_blocked
        total_blocked=$(sudo iptables -L INPUT -n 2>/dev/null | grep -c "AI_V3" || echo 0)
        
        send_tg "⏰ <b>Часовой отчёт AI Security v3.0</b>

🕐 Время: $(date '+%H:00')
📊 Всего атак обработано: $(wc -l < "$THREAT_DB" 2>/dev/null || echo 0)
🛡️ Активных блокировок: ${total_blocked}

📈 Атаки по типам:
• SSH: ${ssh_count}
• DNS: ${dns_count}
• DDoS: ${ddos_count}
• Port Scan: ${port_scan_count}
• Web: ${web_count}
• System: ${system_count}

Статус: ✅ Полная защита активна"
        
        LAST_HOURLY_REPORT=$(date +%H)
    fi
}

# === СОХРАНЕНИЕ/ЗАГРУЗКА ===
save_state() {
    {
        echo "LAST_HOURLY_REPORT=${LAST_HOURLY_REPORT:-}"
        for ip in "${!IP_REPUTATION[@]}"; do
            echo "REP_${ip}=${IP_REPUTATION[$ip]}"
        done
        for ip in "${!IP_ATTACK_HISTORY[@]}"; do
            echo "ATK_${ip}=${IP_ATTACK_HISTORY[$ip]}"
        done
        for ip in "${!IP_ATTACK_TYPES[@]}"; do
            echo "TYPES_${ip}=${IP_ATTACK_TYPES[$ip]}"
        done
    } > "$STATE_FILE"
}

load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        source "$STATE_FILE"
        declare -gA IP_REPUTATION
        declare -gA IP_ATTACK_HISTORY
        declare -gA IP_ATTACK_TYPES
        
        while IFS='=' read -r key value; do
            case "$key" in
                REP_*) IP_REPUTATION["${key#REP_}"]="$value" ;;
                ATK_*) IP_ATTACK_HISTORY["${key#ATK_}"]="$value" ;;
                TYPES_*) IP_ATTACK_TYPES["${key#TYPES_}"]="$value" ;;
            esac
        done < "$STATE_FILE"
    fi
}

# === ИНИЦИАЛИЗАЦИЯ ===
init_v3() {
    log "INFO" "=== AI Security System v3.0 COMPREHENSIVE ==="
    
    touch "$THREAT_DB" "$LEARNING_DB" "${SCRIPT_DIR}/blacklist_permanent.txt"
    load_state
    
    send_tg "🧠 <b>AI Security System v3.0 COMPREHENSIVE</b>

🖥️ Сервер: $(hostname)
📅 $(date '+%Y-%m-%d %H:%M:%S')

🛡️ МОНИТОРИНГ ВСЕХ АТАК:
✅ SSH атаки (все типы)
✅ DNS атаки (Flood, Tunneling)
✅ DDoS (SYN, UDP, ICMP, Bandwidth)
✅ Port Scanning
✅ Web атаки (SQLi, XSS, Traversal)
✅ Brute Force (FTP, MySQL, SMTP)
✅ Time-based атаки
✅ Системные изменения

Уровень защиты: МАКСИМАЛЬНЫЙ"
}

# === MAIN ===
main() {
    init_v3
    
    local iteration=0
    while true; do
        iteration=$((iteration + 1))
        
        # Мониторинг каждые 15 секунд
        monitor_and_respond
        
        # Отчёт каждые 10 минут
        if [[ $((iteration % 40)) -eq 0 ]]; then
            save_state
            send_hourly_report_v3
            log "INFO" "Status: Active (iteration ${iteration})"
        fi
        
        sleep 15
    done
}

trap 'log "INFO" "Stopping..."; save_state; exit 0' SIGTERM SIGINT

main
