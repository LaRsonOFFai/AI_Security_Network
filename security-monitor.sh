#!/bin/bash
#
# Security Monitor для сервера
# Отслеживает атаки и отправляет уведомления в Telegram
#

set -u

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CONFIG_FILE="${SCRIPT_DIR}/tg_config.conf"
STATE_FILE="${SCRIPT_DIR}/state.dat"
LOG_FILE="${SCRIPT_DIR}/monitor.log"

# Загрузка конфигурации
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Конфигурация не найдена! Запустите get-tg-token.sh"
    exit 1
fi
source "$CONFIG_FILE"

# Инициализация состояния
declare -A FAILED_IPS
declare -A BAN_COUNT
LAST_FAIL2BAN_CHECK=0
ATTACK_THRESHOLD=5
CRITICAL_THRESHOLD=10

# Логирование
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Отправка в Telegram
send_tg() {
    local message="$1"
    local parse_mode="HTML"
    
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        -d "text=${message}" \
        -d "parse_mode=${parse_mode}" \
        -d "disable_web_page_preview=true" > /dev/null
    
    log "TG: ${message:0:100}..."
}

# Отправка с фото/документом (для логов)
send_tg_file() {
    local file="$1"
    local caption="$2"
    
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" \
        -d "chat_id=${CHAT_ID}" \
        -d "caption=${caption}" \
        -F "document=@${file}" > /dev/null
}

# Проверка неудачных логинов (real-time)
check_failed_logins() {
    local recent_failures
    recent_failures=$(sudo grep "Failed password" /var/log/auth.log 2>/dev/null | \
        tail -100 | awk '{for(i=1;i<=NF;i++) if($i=="from") print $(i+1)}' | \
        sort | uniq -c | sort -rn | head -20)
    
    if [[ -n "$recent_failures" ]]; then
        while read -r count ip; do
            if [[ $count -ge $CRITICAL_THRESHOLD ]]; then
                # Критическая атака!
                if [[ "${FAILED_IPS[$ip]:-0}" -lt $count ]]; then
                    local country
                    country=$(curl -s "http://ip-api.com/line/${ip}" 2>/dev/null | grep country || echo "Unknown")
                    
                    send_tg "🚨 <b>КРИТИЧЕСКАЯ АТАКА!</b>

📍 IP: <code>${ip}</code>
🌍 Страна: ${country}
🔢 Попыток: ${count}
⏰ Время: $(date '+%H:%M:%S')
🖥️ Сервер: $(hostname)

Статус: Fail2Ban должен заблокировать"
                    
                    FAILED_IPS[$ip]=$count
                fi
            elif [[ $count -ge $ATTACK_THRESHOLD ]]; then
                # Обычная атака
                if [[ "${FAILED_IPS[$ip]:-0}" -lt $count ]]; then
                    send_tg "⚠️ <b>Атака обнаружена</b>

📍 IP: <code>${ip}</code>
🔢 Попыток: ${count}
⏰ Время: $(date '+%H:%M:%S')"
                    
                    FAILED_IPS[$ip]=$count
                fi
            fi
        done <<< "$recent_failures"
    fi
}

# Проверка Fail2Ban
check_fail2ban() {
    local current_time
    current_time=$(date +%s)
    
    # Проверяем каждые 30 секунд
    if [[ $((current_time - LAST_FAIL2BAN_CHECK)) -lt 30 ]]; then
        return
    fi
    LAST_FAIL2BAN_CHECK=$current_time
    
    # Получаем статус Fail2Ban
    local ban_info
    ban_info=$(sudo fail2ban-client status sshd 2>/dev/null)
    
    if [[ -n "$ban_info" ]]; then
        local currently_banned
        currently_banned=$(echo "$ban_info" | grep "Currently banned" | awk '{print $NF}')
        local total_banned
        total_banned=$(echo "$ban_info" | grep "Total banned" | awk '{print $NF}')
        
        # Новая блокировка
        if [[ "$currently_banned" -gt "${LAST_BANNED_COUNT:-0}" ]]; then
            local new_bans=$((currently_banned - LAST_BANNED_COUNT))
            
            # Получаем список забаненных IP
            local banned_list
            banned_list=$(echo "$ban_info" | grep "Banned IP list" | cut -d':' -f2 | tr ' ' '\n' | tail -5)
            
            send_tg "🛡️ <b>Fail2Ban заблокировал атакующих</b>

🔒 Заблокировано: <b>${new_bans}</b> новых IP
📊 Всего в бане: <b>${currently_banned}</b>

Последние IP:
<code>${banned_list}</code>"
        fi
        
        LAST_BANNED_COUNT=$currently_banned
    fi
}

# Проверка подозрительной активности
check_suspicious_activity() {
    # Проверка на rootkit (быстрая)
    if sudo chkrootkit -V &>/dev/null; then
        local rootkit_result
        rootkit_result=$(sudo chkrootkit 2>/dev/null | grep -v "Not infected" | head -5)
        
        if [[ -n "$rootkit_result" ]]; then
            send_tg "🦠 <b>ВОЗМОЖНАЯ ROOTKIT АКТИВНОСТЬ!</b>

⚠️ Обнаружены подозрительные файлы:
<code>${rootkit_result}</code>

Требуется немедленная проверка!"
        fi
    fi
    
    # Проверка на новые SUID файлы
    local new_suid
    new_suid=$(find /usr /bin /sbin -perm -4000 -type f -mtime -1 2>/dev/null)
    
    if [[ -n "$new_suid" && -n "${LAST_SUID_CHECK:-}" ]]; then
        if [[ "$new_suid" != "${LAST_SUID_CHECK}" ]]; then
            send_tg "⚠️ <b>Новые SUID файлы</b>

Обнаружены новые файлы с SUID битом:
<code>${new_suid}</code>"
        fi
    fi
    LAST_SUID_CHECK=$new_suid
}

# Проверка открытых портов
check_open_ports() {
    local current_ports
    current_ports=$(sudo ss -tlnp 2>/dev/null | grep LISTEN | wc -l)
    
    if [[ -n "${LAST_PORT_COUNT:-}" && "$current_ports" -gt "${LAST_PORT_COUNT:-0}" ]]; then
        local new_ports
        new_ports=$(sudo ss -tlnp 2>/dev/null | grep LISTEN)
        
        send_tg "🔌 <b>Открыты новые порты</b>

Количество: ${current_ports}

Порты:
<code>${new_ports}</code>"
    fi
    LAST_PORT_COUNT=$current_ports
}

# Ежедневный отчёт
send_daily_report() {
    local hour
    hour=$(date +%H)
    
    if [[ "$hour" == "09" && "${DAILY_REPORT_SENT:-}" != "$(date +%j)" ]]; then
        local failed_24h
        failed_24h=$(sudo grep "Failed password" /var/log/auth.log 2>/dev/null | \
            wc -l)
        
        local banned_24h
        banned_24h=$(sudo fail2ban-client status sshd 2>/dev/null | \
            grep "Total banned" | awk '{print $NF}')
        
        local top_attackers
        top_attackers=$(sudo grep "Failed password" /var/log/auth.log 2>/dev/null | \
            awk '{for(i=1;i<=NF;i++) if($i=="from") print $(i+1)}' | \
            sort | uniq -c | sort -rn | head -5)
        
        send_tg "📊 <b>Ежедневный отчёт по безопасности</b>

📅 $(date '+%d.%m.%Y')
🖥️ Сервер: $(hostname)

🔴 Неудачных попыток входа: ${failed_24h}
🛡️ Заблокировано IP: ${banned_24h}

🏆 Топ атакующих:
<code>${top_attackers}</code>

Статус: ✅ Угроз не обнаружено"
        
        DAILY_REPORT_SENT=$(date +%j)
    fi
}

# Сохранение состояния
save_state() {
    {
        echo "LAST_BANNED_COUNT=${LAST_BANNED_COUNT:-0}"
        echo "LAST_PORT_COUNT=${LAST_PORT_COUNT:-0}"
        echo "DAILY_REPORT_SENT=${DAILY_REPORT_SENT:-0}"
        echo "LAST_SUID_CHECK=${LAST_SUID_CHECK:-}"
        for ip in "${!FAILED_IPS[@]}"; do
            echo "FAILED_IP_${ip}=${FAILED_IPS[$ip]}"
        done
    } > "$STATE_FILE"
}

# Загрузка состояния
load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        source "$STATE_FILE"
        # Восстанавливаем массив FAILED_IPS
        declare -gA FAILED_IPS
        while IFS='=' read -r key value; do
            if [[ "$key" == FAILED_IP_* ]]; then
                local ip="${key#FAILED_IP_}"
                FAILED_IPS[$ip]="$value"
            fi
        done < "$STATE_FILE"
    fi
}

# Очистка старого состояния (раз в час)
cleanup_state() {
    local current_hour
    current_hour=$(date +%H)
    
    if [[ "${LAST_CLEANUP_HOUR:-}" != "$current_hour" ]]; then
        FAILED_IPS=()
        LAST_CLEANUP_HOUR=$current_hour
        log "State cleaned"
    fi
}

# Основная функция
main() {
    log "=== Security Monitor started ==="
    send_tg "🛡️ <b>Security Monitor запущен</b>

🖥️ Сервер: $(hostname)
📅 $(date '+%Y-%m-%d %H:%M:%S')

Мониторинг активен 24/7"
    
    load_state
    
    local iteration=0
    while true; do
        iteration=$((iteration + 1))
        
        # Каждые 5 секунд
        check_failed_logins
        check_fail2ban
        
        # Каждые 30 секунд
        if [[ $((iteration % 6)) -eq 0 ]]; then
            check_open_ports
        fi
        
        # Каждые 5 минут
        if [[ $((iteration % 60)) -eq 0 ]]; then
            check_suspicious_activity
            cleanup_state
            save_state
            log "Status: OK (iteration ${iteration})"
        fi
        
        # Ежедневный отчёт
        send_daily_report
        
        sleep 5
    done
}

# Обработка сигналов
trap 'log "Stopping..."; save_state; exit 0' SIGTERM SIGINT

# Запуск
main
