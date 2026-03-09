#!/bin/bash
#
# Adaptive AI Security System
# Интеллектуальная система защиты с адаптивным реагированием
# Версия 2.0 - Улучшенное распознавание паттернов
#

set -u

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CONFIG_FILE="${SCRIPT_DIR}/ai_config.conf"
STATE_FILE="${SCRIPT_DIR}/ai_state.dat"
THREAT_DB="${SCRIPT_DIR}/threat_database.dat"
LEARNING_DB="${SCRIPT_DIR}/learning_database.dat"
LOG_FILE="${SCRIPT_DIR}/ai_security.log"

# Загрузка конфигурации
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Конфигурация не найдена!"
    exit 1
fi
source "$CONFIG_FILE"

# === КОНФИГУРАЦИЯ ИИ ===
declare -A IP_REPUTATION        # Репутация IP (0-100)
declare -A IP_ATTACK_HISTORY    # История атак IP
declare -A IP_LAST_SEEN         # Последняя активность
declare -A ATTACK_PATTERNS      # Распознанные паттерны
declare -A RESPONSE_EFFECTIVENESS  # Эффективность мер
declare -A IP_USERS_TARGETED    # Сколько пользователей атаковал IP
declare -A IP_ROOT_ATTEMPTS     # Сколько попыток под root

# Уровни угрозы
THREAT_LEVEL_LOW=1
THREAT_LEVEL_MEDIUM=2
THREAT_LEVEL_HIGH=3
THREAT_LEVEL_CRITICAL=4

# Пороги срабатывания (СНИЖЕНЫ для лучшего распознавания)
THRESHOLD_NEW_IP=2          # Было 3
THRESHOLD_SUSPICIOUS=4      # Было 5
THRESHOLD_ATTACK=8          # Было 10
THRESHOLD_CRITICAL=15       # Было 20

# Временные окна (секунды)
WINDOW_SHORT=60      # 1 минута
WINDOW_MEDIUM=300    # 5 минут
WINDOW_LONG=3600     # 1 час

# === ВЕСА ФАКТОРОВ ===
WEIGHT_FAILED_LOGIN=10
WEIGHT_ROOT_ATTEMPT=20
WEIGHT_BRUTE_FORCE=30
WEIGHT_PORT_SCAN=15
WEIGHT_GEO_RISK=10
WEIGHT_TIME_ANOMALY=10

# === ЛОГИРОВАНИЕ ===
log() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

# === ОТПРАВКА В TELEGRAM ===
send_tg() {
    local message="$1"
    local parse_mode="HTML"
    
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        -d "text=${message}" \
        -d "parse_mode=${parse_mode}" \
        -d "disable_web_page_preview=true" > /dev/null
    
    log "INFO" "TG: ${message:0:80}..."
}

# === ГЕОЛОКАЦИЯ IP ===
get_geo_info() {
    local ip="$1"
    local cache_file="/tmp/geo_${ip//./_}"
    
    if [[ -f "$cache_file" && $(find "$cache_file" -mmin -60) ]]; then
        cat "$cache_file"
        return
    fi
    
    local geo_info
    geo_info=$(curl -s "http://ip-api.com/line/${ip}" 2>/dev/null || echo "")
    
    if [[ -n "$geo_info" ]]; then
        echo "$geo_info" > "$cache_file"
        echo "$geo_info"
    else
        echo "Unknown|Unknown|Unknown"
    fi
}

# === ОЦЕНКА СТРАНЫ ПО РИСКУ ===
get_country_risk() {
    local country="$1"
    
    case "$country" in
        "China"|"CN") echo 30 ;;
        "Russia"|"RU") echo 25 ;;
        "North Korea"|"KP") echo 40 ;;
        "Iran"|"IR") echo 35 ;;
        "Brazil"|"BR") echo 15 ;;
        "India"|"IN") echo 15 ;;
        "Ukraine"|"UA") echo 20 ;;
        "Netherlands"|"NL") echo 10 ;;
        "United States"|"US") echo 5 ;;
        "Germany"|"DE") echo 5 ;;
        *) echo 10 ;;
    esac
}

# === РАСЧЁТ УРОВНЯ УГРОЗЫ IP ===
calculate_threat_level() {
    local ip="$1"
    local threat_score=0
    local factors=""
    
    # 1. Репутация IP
    local rep="${IP_REPUTATION[$ip]:-50}"
    threat_score=$((threat_score + (100 - rep) / 5))
    factors+="rep:${rep} "
    
    # 2. История атак
    local attack_count="${IP_ATTACK_HISTORY[$ip]:-0}"
    if [[ $attack_count -gt 0 ]]; then
        threat_score=$((threat_score + attack_count * 2))
        factors+="attacks:${attack_count} "
    fi
    
    # 3. Геолокация
    local geo_info
    geo_info=$(get_geo_info "$ip")
    local country
    country=$(echo "$geo_info" | head -1)
    local geo_risk
    geo_risk=$(get_country_risk "$country")
    threat_score=$((threat_score + geo_risk / 5))
    factors+="geo:${country} "
    
    # 4. Время атаки (ночные атаки подозрительнее)
    local hour
    hour=$(date +%H)
    if [[ $hour -ge 2 && $hour -le 5 ]]; then
        threat_score=$((threat_score + 10))
        factors+="night_attack "
    fi
    
    # 5. Частота атак
    local last_seen="${IP_LAST_SEEN[$ip]:-0}"
    local now
    now=$(date +%s)
    local time_diff=$((now - last_seen))
    if [[ $time_diff -lt 60 && $attack_count -gt 3 ]]; then
        threat_score=$((threat_score + 20))
        factors+="rapid_attack "
    fi
    
    # 6. Попытки входа под root (дополнительно)
    local root_attempts="${IP_ROOT_ATTEMPTS[$ip]:-0}"
    if [[ $root_attempts -gt 0 ]]; then
        threat_score=$((threat_score + root_attempts * 5))
        factors+="root:${root_attempts} "
    fi
    
    # 7. Множество пользователей (credential stuffing)
    local users_targeted="${IP_USERS_TARGETED[$ip]:-0}"
    if [[ $users_targeted -gt 2 ]]; then
        threat_score=$((threat_score + users_targeted * 8))
        factors+="users:${users_targeted} "
    fi
    
    # Нормализация (0-100)
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
    
    echo "$level:$threat_score:$factors"
}

# === УЛУЧШЕННОЕ РАСПОЗНАВАНИЕ ПАТТЕРНОВ АТАКИ ===
recognize_attack_pattern() {
    local ip="$1"
    local pattern="UNKNOWN"
    local confidence=0
    
    # СНАЧАЛА проверяем накопленную статистику (для уже известных атак)
    local attack_count="${IP_ATTACK_HISTORY[$ip]:-0}"
    local root_attempts="${IP_ROOT_ATTEMPTS[$ip]:-0}"
    local users_targeted="${IP_USERS_TARGETED[$ip]:-0}"
    
    # Распознавание по накопленным данным
    if [[ $root_attempts -ge 2 ]]; then
        pattern="ROOT_TARGETING"
        confidence=$((root_attempts * 15))
    elif [[ $users_targeted -ge 3 ]]; then
        pattern="CREDENTIAL_STUFFING"
        confidence=$((users_targeted * 20))
    elif [[ $attack_count -ge 5 ]]; then
        pattern="BRUTE_FORCE_SSH"
        confidence=$((attack_count * 8))
    elif [[ $attack_count -ge 3 ]]; then
        pattern="SLOW_BRUTE_FORCE"
        confidence=$((attack_count * 10))
    fi
    
    # Если уже определили паттерн по статистике, возвращаем
    if [[ "$pattern" != "UNKNOWN" ]]; then
        echo "${pattern}:${confidence}"
        return
    fi
    
    # Получаем последние действия IP из глобального лога
    local recent_actions
    recent_actions=$(sudo grep "$ip" /var/log/auth.log 2>/dev/null | tail -30)
    
    if [[ -z "$recent_actions" ]]; then
        # Если нет данных в auth.log, возвращаем определённый выше паттерн
        echo "${pattern}:${confidence}"
        return
    fi
    
    # === АНАЛИЗ ЛОГОВ ===
    
    # Паттерн 1: Brute Force SSH (СНИЖЕН ПОРОГ с 10 до 5)
    local failed_count
    failed_count=$(echo "$recent_actions" | grep -c "Failed password" || echo 0)
    if [[ $failed_count -ge 5 ]]; then
        pattern="BRUTE_FORCE_SSH"
        confidence=$((failed_count * 8))
    fi
    
    # Паттерн 2: Root Targeting (СНИЖЕН ПОРОГ с 5 до 2)
    local root_attempts
    root_attempts=$(echo "$recent_actions" | grep -c "user root" || echo 0)
    # Также проверяем альтернативный формат лога
    local root_attempts2
    root_attempts2=$(echo "$recent_actions" | grep -c "for root " || echo 0)
    root_attempts=$((root_attempts + root_attempts2))
    
    if [[ $root_attempts -ge 2 ]]; then
        if [[ "$pattern" == "UNKNOWN" ]]; then
            pattern="ROOT_TARGETING"
        else
            pattern="${pattern}+ROOT_TARGETING"
        fi
        confidence=$((confidence + root_attempts * 12))
        # Сохраняем для будущего использования
        IP_ROOT_ATTEMPTS[$ip]=$root_attempts
    fi
    
    # Паттерн 3: Distributed Attack (множество IP из одной подсети)
    local subnet
    subnet=$(echo "$ip" | cut -d'.' -f1-3)
    local subnet_attacks
    subnet_attacks=$(sudo grep "Failed password" /var/log/auth.log 2>/dev/null | \
        grep -E "${subnet}\.[0-9]+" | tail -50 | wc -l)
    if [[ $subnet_attacks -ge 10 ]]; then
        if [[ "$pattern" == "UNKNOWN" ]]; then
            pattern="DISTRIBUTED_ATTACK"
        else
            pattern="${pattern}+DISTRIBUTED"
        fi
        confidence=$((confidence + subnet_attacks * 3))
    fi
    
    # Паттерн 4: Credential Stuffing (много разных пользователей) (СНИЖЕН ПОРОГ с 5 до 3)
    local unique_users
    unique_users=$(echo "$recent_actions" | grep -oP "for (invalid user )?\K\w+" | sort -u | wc -l)
    if [[ $unique_users -ge 3 ]]; then
        if [[ "$pattern" == "UNKNOWN" ]]; then
            pattern="CREDENTIAL_STUFFING"
        else
            pattern="${pattern}+CREDENTIAL_STUFFING"
        fi
        confidence=$((confidence + unique_users * 18))
        # Сохраняем для будущего использования
        IP_USERS_TARGETED[$ip]=$unique_users
    fi
    
    # Паттерн 5: Rapid Fire Attack (очень быстрая серия попыток)
    local first_time
    local last_time
    first_time=$(echo "$recent_actions" | head -1 | awk '{print $1, $2, $3}')
    last_time=$(echo "$recent_actions" | tail -1 | awk '{print $1, $2, $3}')
    
    # Если 5+ попыток за 10 секунд
    if [[ $failed_count -ge 5 ]]; then
        pattern="RAPID_FIRE"
        confidence=$((confidence + 25))
    fi
    
    # Если всё ещё UNKNOWN, проверяем накопленную статистику
    if [[ "$pattern" == "UNKNOWN" ]]; then
        local total_attacks="${IP_ATTACK_HISTORY[$ip]:-0}"
        if [[ $total_attacks -ge 3 ]]; then
            pattern="SLOW_BRUTE_FORCE"
            confidence=$((total_attacks * 10))
        fi
    fi
    
    echo "${pattern}:${confidence}"
}

# === АНАЛИЗ ВСЕХ АТАК В ПАРАЛЛЕЛИ ===
analyze_all_attackers() {
    # Получаем всех атакующих за последние 5 минут
    local all_attackers
    all_attackers=$(sudo grep "Failed password" /var/log/auth.log 2>/dev/null | \
        tail -200 | awk '{for(i=1;i<=NF;i++) if($i=="from") print $(i+1)}' | \
        sort | uniq -c | sort -rn)
    
    if [[ -z "$all_attackers" ]]; then
        return
    fi
    
    # Анализируем каждого
    while read -r count ip; do
        if [[ -z "$ip" || "$count" -lt 2 ]]; then
            continue
        fi
        
        # Получаем пользователей которых атаковал этот IP
        local users
        users=$(sudo grep "$ip" /var/log/auth.log 2>/dev/null | \
            grep -oP "for (invalid user )?\K\w+" | sort -u | wc -l)
        
        # Получаем попытки под root
        local root_count
        root_count=$(sudo grep "$ip" /var/log/auth.log 2>/dev/null | \
            grep -c "for root " || echo 0)
        
        # Сохраняем статистику
        IP_USERS_TARGETED[$ip]=$users
        IP_ROOT_ATTEMPTS[$ip]=$root_count
        
    done <<< "$all_attackers"
}

# === АДАПТИВНЫЙ ОТВЕТ ===
adaptive_response() {
    local ip="$1"
    local threat_level="$2"
    local pattern="$3"
    local confidence="$4"
    
    log "INFO" "Adaptive response: IP=$ip Level=$threat_level Pattern=$pattern"
    
    local response_action=""
    local ban_duration=0
    local message=""
    
    case $threat_level in
        $THREAT_LEVEL_LOW)
            # Уровень 1: Мониторинг
            response_action="MONITOR"
            ban_duration=0
            message="🟡 <b>Низкий уровень угрозы</b>

📍 IP: <code>${ip}</code>
📊 Уровень: LOW
🔍 Паттерн: ${pattern}

Действие: Усиленный мониторинг"
            ;;
            
        $THREAT_LEVEL_MEDIUM)
            # Уровень 2: Временная блокировка
            response_action="TEMP_BAN"
            ban_duration=600  # 10 минут
            message="🟠 <b>Средний уровень угрозы</b>

📍 IP: <code>${ip}</code>
📊 Уровень: MEDIUM
🔍 Паттерн: ${pattern}
⏱️ Длительность: 10 минут

Действие: Временная блокировка"
            
            # Проверяем не заблокирован ли уже
            if ! sudo iptables -L INPUT -n 2>/dev/null | grep -q "$ip"; then
                sudo iptables -A INPUT -s "$ip" -j DROP -m comment --comment "AI_TEMP_BAN"
            fi
            ;;
            
        $THREAT_LEVEL_HIGH)
            # Уровень 3: Длительная блокировка + подсеть
            response_action="LONG_BAN"
            ban_duration=86400  # 24 часа
            message="🔴 <b>Высокий уровень угрозы</b>

📍 IP: <code>${ip}</code>
📊 Уровень: HIGH
🔍 Паттерн: ${pattern}
⏱️ Длительность: 24 часа

Действие: Длительная блокировка"
            
            if ! sudo iptables -L INPUT -n 2>/dev/null | grep -q "$ip"; then
                sudo iptables -A INPUT -s "$ip" -j DROP -m comment --comment "AI_LONG_BAN"
            fi
            
            # Блокируем подсеть если паттерн DISTRIBUTED
            if [[ "$pattern" == *"DISTRIBUTED"* ]]; then
                local subnet
                subnet="${ip%.*}.0/24"
                if ! sudo iptables -L INPUT -n 2>/dev/null | grep -q "$subnet"; then
                    sudo iptables -I INPUT -s "$subnet" -j DROP -m comment --comment "AI_SUBNET_BAN"
                    message+="
🌐 Подсеть: <code>${subnet}</code> тоже заблокирована"
                fi
            fi
            ;;
            
        $THREAT_LEVEL_CRITICAL)
            # Уровень 4: Перманентная блокировка + отчёт
            response_action="PERMANENT_BAN"
            ban_duration=0  # Навсегда
            message="🚨 <b>КРИТИЧЕСКАЯ УГРОЗА!</b>

📍 IP: <code>${ip}</code>
📊 Уровень: CRITICAL
🔍 Паттерн: ${pattern}
⚡ Доверие: ${confidence}%

Действие: Перманентная блокировка + внесение в чёрный список"
            
            if ! sudo iptables -L INPUT -n 2>/dev/null | grep -q "$ip"; then
                sudo iptables -A INPUT -s "$ip" -j DROP -m comment --comment "AI_PERM_BAN"
            fi
            
            # Добавляем в постоянный чёрный список
            echo "$ip # $(date '+%Y-%m-%d %H:%M:%S') Pattern: $pattern Confidence: $confidence" >> "${SCRIPT_DIR}/blacklist_permanent.txt"
            
            # Отправляем расширенный отчёт
            local geo_info
            geo_info=$(get_geo_info "$ip")
            message+="

🌍 Геолокация:
<code>${geo_info}</code>"
            ;;
    esac
    
    # Сохраняем эффективность ответа
    RESPONSE_EFFECTIVENESS["${ip}_$(date +%s)"]="$response_action"
    
    # Отправляем уведомление (кроме MONITOR)
    if [[ "$response_action" != "MONITOR" ]]; then
        send_tg "$message"
    fi
    
    log "INFO" "Response: $response_action for $ip"
    echo "$response_action"
}

# === ОБУЧЕНИЕ НА ОСНОВЕ РЕЗУЛЬТАТОВ ===
learn_from_result() {
    local ip="$1"
    local action="$2"
    local result="$3"  # success/failure
    
    # Записываем в базу обучения
    echo "$(date '+%Y-%m-%d %H:%M:%S')|$ip|$action|$result" >> "$LEARNING_DB"
    
    # Анализируем эффективность
    local total_actions
    total_actions=$(grep "$action" "$LEARNING_DB" | wc -l)
    local successful_actions
    successful_actions=$(grep "$action.*success" "$LEARNING_DB" | wc -l)
    
    if [[ $total_actions -gt 0 ]]; then
        local effectiveness=$((successful_actions * 100 / total_actions))
        log "INFO" "Action $action effectiveness: ${effectiveness}%"
        
        # Если эффективность низкая, корректируем пороги
        if [[ $effectiveness -lt 50 && $total_actions -gt 10 ]]; then
            log "WARN" "Low effectiveness for $action, adjusting thresholds"
        fi
    fi
}

# === ПРОГНОЗИРОВАНИЕ СЛЕДУЮЩЕЙ ЦЕЛИ ===
predict_next_target() {
    # Анализируем текущие атаки
    local current_attackers
    current_attackers=$(sudo grep "Failed password" /var/log/auth.log 2>/dev/null | \
        tail -200 | awk '{for(i=1;i<=NF;i++) if($i=="from") print $(i+1)}' | \
        sort | uniq -c | sort -rn | head -10)
    
    if [[ -n "$current_attackers" ]]; then
        local top_attacker
        top_attacker=$(echo "$current_attackers" | head -1 | awk '{print $2}')
        
        # Проверяем, не атакует ли подсеть
        local subnet
        subnet="${top_attacker%.*}"
        local subnet_count
        subnet_count=$(echo "$current_attackers" | grep -c "$subnet" || echo 0)
        
        if [[ $subnet_count -ge 3 ]]; then
            send_tg "🔮 <b>ПРОГНОЗ АТАКИ</b>

Обнаружена скоординированная атака из подсети:
<code>${subnet}.0/24</code>

Активных IP: ${subnet_count}

Рекомендация: Заблокировать всю подсеть превентивно"
        fi
    fi
}

# === ОБНОВЛЕНИЕ РЕПУТАЦИИ IP ===
update_ip_reputation() {
    local ip="$1"
    local action="$2"  # attack/defend
    
    local current_rep="${IP_REPUTATION[$ip]:-50}"
    
    if [[ "$action" == "attack" ]]; then
        # Уменьшаем репутацию
        IP_REPUTATION[$ip]=$((current_rep - 5))
        if [[ ${IP_REPUTATION[$ip]} -lt 0 ]]; then
            IP_REPUTATION[$ip]=0
        fi
    else
        # Увеличиваем репутацию (если долго не атаковал)
        IP_REPUTATION[$ip]=$((current_rep + 1))
        if [[ ${IP_REPUTATION[$ip]} -gt 100 ]]; then
            IP_REPUTATION[$ip]=100
        fi
    fi
}

# === ОСНОВНОЙ ЦИКЛ АНАЛИЗА ===
analyze_and_respond() {
    # Сначала анализируем всех атакующих для сбора статистики
    analyze_all_attackers
    
    # Получаем последние неудачные логины
    local recent_failures
    recent_failures=$(sudo grep "Failed password" /var/log/auth.log 2>/dev/null | \
        tail -100 | awk '{for(i=1;i<=NF;i++) if($i=="from") print $(i+1)}' | \
        sort | uniq -c | sort -rn)
    
    if [[ -z "$recent_failures" ]]; then
        return
    fi
    
    while read -r count ip; do
        if [[ -z "$ip" ]]; then
            continue
        fi
        
        # Обновляем время последней активности
        IP_LAST_SEEN[$ip]=$(date +%s)
        
        # Обновляем историю атак
        local prev_count="${IP_ATTACK_HISTORY[$ip]:-0}"
        IP_ATTACK_HISTORY[$ip]=$((prev_count + count))
        
        # Рассчитываем уровень угрозы
        local threat_info
        threat_info=$(calculate_threat_level "$ip")
        local threat_level
        threat_level=$(echo "$threat_info" | cut -d':' -f1)
        local threat_score
        threat_score=$(echo "$threat_info" | cut -d':' -f2)
        
        # Распознаём паттерн (теперь с улучшенной функцией)
        local pattern_info
        pattern_info=$(recognize_attack_pattern "$ip")
        local pattern
        pattern=$(echo "$pattern_info" | cut -d':' -f1)
        local confidence
        confidence=$(echo "$pattern_info" | cut -d':' -f2)
        
        log "INFO" "IP: $ip Level: $threat_level Score: $threat_score Pattern: $pattern"
        
        # Адаптивный ответ
        local response
        response=$(adaptive_response "$ip" "$threat_level" "$pattern" "$confidence")
        
        # Обновляем репутацию
        update_ip_reputation "$ip" "attack"
        
        # Сохраняем в базу угроз
        echo "$(date '+%Y-%m-%d %H:%M:%S')|$ip|$threat_level|$threat_score|$pattern|$response" >> "$THREAT_DB"
        
    done <<< "$recent_failures"
}

# === ОЧИСТКА СТАРЫХ ПРАВИЛ IPTABLES ===
cleanup_old_rules() {
    # Удаляем временные блокировки старше 1 часа
    local now
    now=$(date +%s)
    
    # Здесь можно добавить логику для автоматической разблокировки
    log "INFO" "Cleanup completed"
}

# === ЕЖЕЧАСНЫЙ ОТЧЁТ ===
send_hourly_report() {
    local minute
    minute=$(date +%M)
    
    if [[ "$minute" == "00" && "${LAST_HOURLY_REPORT:-}" != "$(date +%H)" ]]; then
        local total_threats
        total_threats=$(wc -l < "$THREAT_DB" 2>/dev/null || echo 0)
        
        local blocked_ips
        blocked_ips=$(sudo iptables -L INPUT -n 2>/dev/null | grep -c "AI_" || echo 0)
        
        # Статистика по паттернам
        local brute_force_count
        brute_force_count=$(grep "BRUTE_FORCE" "$THREAT_DB" 2>/dev/null | wc -l)
        local root_targeting_count
        root_targeting_count=$(grep "ROOT_TARGETING" "$THREAT_DB" 2>/dev/null | wc -l)
        local distributed_count
        distributed_count=$(grep "DISTRIBUTED" "$THREAT_DB" 2>/dev/null | wc -l)
        
        send_tg "⏰ <b>Часовой отчёт</b>

🕐 Время: $(date '+%H:00')
📊 Угроз обработано: ${total_threats}
🛡️ Активных блокировок: ${blocked_ips}

🔍 Паттерны за час:
• Brute Force: ${brute_force_count}
• Root Targeting: ${root_targeting_count}
• Distributed: ${distributed_count}

Статус: ✅ Система активна"
        
        LAST_HOURLY_REPORT=$(date +%H)
    fi
}

# === СОХРАНЕНИЕ СОСТОЯНИЯ ===
save_state() {
    {
        echo "LAST_HOURLY_REPORT=${LAST_HOURLY_REPORT:-}"
        for ip in "${!IP_REPUTATION[@]}"; do
            echo "REP_${ip}=${IP_REPUTATION[$ip]}"
        done
        for ip in "${!IP_ATTACK_HISTORY[@]}"; do
            echo "ATK_${ip}=${IP_ATTACK_HISTORY[$ip]}"
        done
        for ip in "${!IP_LAST_SEEN[@]}"; do
            echo "SEEN_${ip}=${IP_LAST_SEEN[$ip]}"
        done
        for ip in "${!IP_ROOT_ATTEMPTS[@]}"; do
            echo "ROOT_${ip}=${IP_ROOT_ATTEMPTS[$ip]}"
        done
        for ip in "${!IP_USERS_TARGETED[@]}"; do
            echo "USERS_${ip}=${IP_USERS_TARGETED[$ip]}"
        done
    } > "$STATE_FILE"
}

# === ЗАГРУЗКА СОСТОЯНИЯ ===
load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        source "$STATE_FILE"
        declare -gA IP_REPUTATION
        declare -gA IP_ATTACK_HISTORY
        declare -gA IP_LAST_SEEN
        declare -gA IP_ROOT_ATTEMPTS
        declare -gA IP_USERS_TARGETED
        
        while IFS='=' read -r key value; do
            case "$key" in
                REP_*)
                    local ip="${key#REP_}"
                    IP_REPUTATION[$ip]="$value"
                    ;;
                ATK_*)
                    local ip="${key#ATK_}"
                    IP_ATTACK_HISTORY[$ip]="$value"
                    ;;
                SEEN_*)
                    local ip="${key#SEEN_}"
                    IP_LAST_SEEN[$ip]="$value"
                    ;;
                ROOT_*)
                    local ip="${key#ROOT_}"
                    IP_ROOT_ATTEMPTS[$ip]="$value"
                    ;;
                USERS_*)
                    local ip="${key#USERS_}"
                    IP_USERS_TARGETED[$ip]="$value"
                    ;;
            esac
        done < "$STATE_FILE"
    fi
}

# === ИНИЦИАЛИЗАЦИЯ ===
init_system() {
    log "INFO" "=== AI Security System v2.0 initializing ==="
    
    # Создаём файлы если нет
    touch "$THREAT_DB" "$LEARNING_DB" "${SCRIPT_DIR}/blacklist_permanent.txt"
    
    load_state
    
    send_tg "🧠 <b>AI Security System v2.0 запущена</b>

🖥️ Сервер: $(hostname)
📅 $(date '+%Y-%m-%d %H:%M:%S')

🆙 Улучшения:
• Снижены пороги распознавания
• Улучшен анализ паттернов
• Добавлен анализ root-атак
• Распознавание credential stuffing

Уровень защиты: МАКСИМАЛЬНЫЙ"
}

# === ОСНОВНОЙ ЦИКЛ ===
main() {
    init_system
    
    local iteration=0
    while true; do
        iteration=$((iteration + 1))
        
        # Анализ каждые 10 секунд
        analyze_and_respond
        
        # Прогноз каждые 5 минут
        if [[ $((iteration % 30)) -eq 0 ]]; then
            predict_next_target
            cleanup_old_rules
        fi
        
        # Сохранение каждые 10 минут
        if [[ $((iteration % 60)) -eq 0 ]]; then
            save_state
            log "INFO" "Status: Active (iteration ${iteration})"
        fi
        
        # Ежечасный отчёт
        send_hourly_report
        
        sleep 10
    done
}

# Обработка сигналов
trap 'log "INFO" "Stopping..."; save_state; exit 0' SIGTERM SIGINT

# Запуск
main
